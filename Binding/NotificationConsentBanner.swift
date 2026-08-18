import SwiftUI

struct NotificationConsentBanner: View {
    @ObservedObject var manager: NotificationEnrollmentManager = .shared

    var body: some View {
        if manager.needsTermsAcceptance {
            banner {
                consentContent
            }
        } else if manager.pushPermissionGranted && !manager.isDeviceRegistered {
            banner {
                enrollmentContent
            }
        } else if let error = manager.lastRegistrationError, !error.isEmpty {
            banner {
                registrationErrorContent(error)
            }
        }
    }

    private var consentContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktiver varsler")
                .font(.headline)
            Text("For å varsle deg om møterespons og handlinger som krever enheten din, må du lagre en enhets-ID og push-token og gi tillatelse til varsling.")
                .font(.subheadline)
            HStack {
                Button("Ikke nå (før registrering)") {
                    Task { await manager.declineTermsBeforeRegistration() }
                }
                .buttonStyle(.bordered)

                Button("Godta og fortsett") {
                    Task { await manager.acceptTermsAndEnableNotifications() }
                }
                .buttonStyle(.borderedProminent)
            }
            registrationErrorText
        }
    }

    @ViewBuilder
    private var enrollmentContent: some View {
        switch manager.enrollmentPhase {
        case .completionRequired:
            identityLinkRequiredContent
        case .completionStaged, .registering:
            registrationInProgressContent
        case .statusReadbackRequired:
            statusReadbackContent
        case .retryable:
            registrationRetryContent
        case .apnsTokenPending:
            apnsTokenPendingContent
        case .termsRequired, .pushPermissionRequired:
            registrationRetryContent
        }
    }

    private var identityLinkRequiredContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sikker enhetskobling kreves")
                .font(.headline)
            Text("Før telefonen kan registreres hos staging må HAVEN fullføre den samme kortlivede Identity Link-handshaken som Scaffold Setup utsteder.")
                .font(.subheadline)
            Button("Åpne Identity Link") {
                BindingPortholeLoadBridge.post(
                    configuration: ConfigurationCatalogCell
                        .conferenceIdentityLinkWorkbenchConfiguration()
                )
            }
            .buttonStyle(.borderedProminent)
            registrationErrorText
        }
    }

    private var registrationInProgressContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Registrerer enheten sikkert")
                .font(.headline)
            Text("Identity Link er verifisert. HAVEN bruker engangskonvolutten i ett signert registreringsforsøk.")
                .font(.subheadline)
            ProgressView()
            registrationErrorText
        }
    }

    private var apnsTokenPendingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Venter på varslingstoken")
                .font(.headline)
            Text("HAVEN har tillatelse og fortsetter når iOS har levert et ferskt APNs-token.")
                .font(.subheadline)
            ProgressView()
            registrationErrorText
        }
    }

    private var statusReadbackContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Registreringskvittering verifisert")
                .font(.headline)
            Text("HAVEN venter på en fersk, signert statuslesing før enheten kan vises som aktivt registrert.")
                .font(.subheadline)
            registrationErrorText
        }
    }

    private var registrationRetryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Varsler ikke registrert")
                .font(.headline)
            Text("HAVEN har varslingsrettighet, men telefonen er ikke registrert hos staging ennå.")
                .font(.subheadline)
            Button("Registrer på nytt") {
                Task { await manager.retryDeviceRegistration() }
            }
            .buttonStyle(.borderedProminent)
            registrationErrorText
        }
    }

    private func registrationErrorContent(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Varslingsregistrering feilet")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
            Button("Prøv igjen") {
                Task { await manager.retryDeviceRegistration() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var registrationErrorText: some View {
        Group {
            if let error = manager.lastRegistrationError, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func banner<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.top, 12)
    }
}
