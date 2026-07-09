#if DEBUG
import CotermMobileShellModel

@MainActor
final class DeleteComputersVerifierIdentityProvider: MobileIdentityProviding {
    let currentUserID: String?

    init(userID: String?) {
        currentUserID = userID
    }
}
#endif
