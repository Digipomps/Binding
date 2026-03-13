import Foundation

public enum LaunchAgentTemplate {
    public static func render(
        label: String = "io.digipomps.haven.agentd",
        executablePath: String,
        configPath: String,
        logDirectory: String
    ) -> String {
        let escapedExecutablePath = escape(executablePath)
        let escapedConfigPath = escape(configPath)
        let escapedLogDirectory = escape(logDirectory)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(escapedExecutablePath)</string>
                <string>run</string>
                <string>--config</string>
                <string>\(escapedConfigPath)</string>
            </array>
            <key>KeepAlive</key>
            <true/>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(escapedLogDirectory)/stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(escapedLogDirectory)/stderr.log</string>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
