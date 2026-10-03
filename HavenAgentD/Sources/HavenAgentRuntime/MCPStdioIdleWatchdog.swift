import Darwin
import Foundation

/// Avslutter en stdio-MCP-server som ikke lenger har en levende klient.
///
/// En stdio-MCP skal avslutte naar klienten lukker stdin: `readLine()`
/// returnerer `nil`, loekka faller ut, og prosessen doer. Begge HAVEN-serverne
/// gjoer nettopp det - og likevel hopet de seg opp.
///
/// Aarsaken ligger hos klienten. Codex kjoerer som én langlevende
/// `codex mcp-server`-prosess og starter ett sett MCP-servere per
/// samtaletraad. Naar traaden tar slutt, avsluttes ikke barnet og stdin lukkes
/// ikke - roerledningen holdes aapen av foreldreprosessen som fortsatt lever.
/// EOF kommer derfor aldri. Serveren blir staaende og sove i `read()` for
/// alltid, og det blir én ny for hvert kall. Observert 26. august 2026: tolv
/// `haven-agentd-mcp` og tolv `haven-correspondence-mcp` samtidig, alle med
/// samme forelder, alle i tilstand `S`, alle med fd 0 aapen mot en pipe med
/// levende skriver.
///
/// Vakthunden fjerner avhengigheten til at klienten oppfoerer seg. Har det
/// ikke kommet en eneste melding paa `timeout` sekunder, avslutter prosessen
/// seg selv. Det er trygt fordi det er selve kontrakten for stdio-transporten:
/// en klient som trenger en server, starter den. En som ikke har snakket paa et
/// kvarter, har ikke bruk for den.
///
/// Vinduet settes med `--idle-timeout <sekunder>` eller
/// `HAVEN_MCP_IDLE_TIMEOUT_SECONDS`. Null eller mindre slaar den av.
public final class MCPStdioIdleWatchdog: @unchecked Sendable {
    public static let shared = MCPStdioIdleWatchdog()

    /// Rikelig for en klient som faktisk jobber, kort nok til at en forlatt
    /// prosess ikke overlever arbeidsdagen.
    public static let defaultTimeout: TimeInterval = 900

    private let lock = NSLock()
    private var lastActivity = Date()
    private var started = false

    private init() {}

    /// Flagg vinner over miljoevariabel, miljoevariabel over standardverdien.
    public static func configuredTimeout(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TimeInterval {
        if let index = arguments.firstIndex(of: "--idle-timeout"),
            arguments.indices.contains(index + 1),
            let parsed = TimeInterval(arguments[index + 1])
        {
            return parsed
        }
        if let raw = environment["HAVEN_MCP_IDLE_TIMEOUT_SECONDS"],
            let parsed = TimeInterval(raw)
        {
            return parsed
        }
        return defaultTimeout
    }

    /// Kalles for hver innkommende linje. Billig med vilje - dette staar i
    /// den varme loekka.
    public func noteActivity() {
        lock.lock()
        lastActivity = Date()
        lock.unlock()
    }

    /// Idempotent. `timeout <= 0` slaar av vakthunden.
    public func start(serverName: String, timeout: TimeInterval = configuredTimeout()) {
        guard timeout > 0 else { return }

        lock.lock()
        if started {
            lock.unlock()
            return
        }
        started = true
        lastActivity = Date()
        lock.unlock()

        // Sjekk ofte nok til at avslutningen skjer naer grensen, sjeldent nok
        // til at en sovende prosess ikke koster noe.
        let interval = min(30, max(1, timeout / 4))
        let thread = Thread { [weak self] in
            while true {
                Thread.sleep(forTimeInterval: interval)
                guard let self else { return }
                self.lock.lock()
                let idle = Date().timeIntervalSince(self.lastActivity)
                self.lock.unlock()
                guard idle >= timeout else { continue }
                let message =
                    "\(serverName): ingen MCP-melding paa \(Int(idle)) s (grense \(Int(timeout)) s). "
                    + "Klienten forlot stdio uten aa lukke stdin. Avslutter i stedet for aa bli liggende.\n"
                FileHandle.standardError.write(Data(message.utf8))
                Darwin.exit(0)
            }
        }
        thread.name = "haven.mcp.idle-watchdog"
        thread.start()
    }
}
