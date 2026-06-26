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
                registrationRetryContent
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
                Button("Ikke nå") {
                    manager.declineTerms()
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

    private var registrationRetryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Varsler ikke registrert")
                .font(.headline)
            Text("Binding har varslingsrettighet, men telefonen er ikke registrert hos staging ennå.")
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
