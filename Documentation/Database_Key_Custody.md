# Private celledata – native eiergodkjenning

Formålet er at én celles private data og databasenøkkel følger eierens tilgang,
uten å bli en delt scaffold-ressurs eller en generisk modellhandling.

Åpne **HAVEN → Private celledata …** på macOS. Opprett en separat Keychain-mottaker,
eksporter bare den offentlige referansen og bruk en uavhengig recovery-mottaker
på en annen betrodd enhet. Det eksisterende nøkkelhåndtaket blir aldri erstattet
ved åpning, gjenoppretting eller et manglende Keychain-element.

Godkjenning begynner med privat import av `DatabaseOwnerApprovalPackage` fra en
kjent tjeneste. Kontroller celle, databasefil, tjenesteidentitet, audience,
formål, nøkkel/policyversjon og utløp. Binding krever en allerede tilgjengelig
eieridentitet for riktig domene, henter den signerte posten fra HTTPS-verten og
ber Keychain om fersk brukerautorisasjon. Eksporter `DatabaseServiceGrant` tilbake
til tjenestens dedikerte grant-endepunkt. Det gir bare én avledet filnøkkel til
én fersk mottaker, aldri celleroten eller en privat opplåsingsnøkkel.

Lokal låsing avbryter ventende godkjenning. En allerede eksportert tjenestenøkkel
må låses på tjenesten eller utløpe. En ondsinnet godkjent tjeneste kan beholde
nøkkelen og lest klartekst; kompromittert cellerot krever flerfilrotasjon i
CellScaffold. TTL er ikke kryptografisk tilbakekalling.

Mottakerreferanser og siste aksepterte signerte versjon lagres privat lokalt.
Ved første registrering trenger eieren en betrodd aktuell versjonsreferanse.
Nøkler går ikke gjennom chat, Skeleton, Flow, logging eller generiske verktøy.
Dette er Keychain-beskyttet X25519 i programvare, ikke Secure Enclave.

Implementasjon: `DatabaseKeyCustodyView`, CellApple `AppleDatabaseOwnerApproval`
og `AppleDatabaseSecretUnwrapper`; de delte kontraktene ligger i CellBase.
Full arkitektur og driftsoppsett: CellScaffold `Documentation/Cell_Database_Key_Custody.md`.

Den signerte Keychain-testen er eksplisitt opt-in (`HAVEN_RUN_KEYCHAIN_ACCEPTANCE=1`)
og bruker bare midlertidige, unike testelementer. En vanlig grønn enhetstest uten
flagget beviser ikke brukerautorisasjon eller fysisk enhetslås. Faktiske resultater
skal dokumenteres separat, ikke utledes fra at adapteren kompilerer.
