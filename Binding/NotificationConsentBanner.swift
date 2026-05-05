import SwiftUI

struct NotificationConsentBanner: View {
    @ObservedObject var manager: NotificationEnrollmentManager = .shared

    var body: some View {
        if manager.needsTermsAcceptance {
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
                if let error = manager.lastRegistrationError, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
    }
}

