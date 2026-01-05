import UIKit

final class EndlessModeCoordinator: GameModeCoordinating {
    let kind: GameModeKind = .endless
    let title: String = "无尽"
    let iconName: String = "infinity"

    weak var presentingViewController: UIViewController?
    var onStartRequested: (() -> Void)?

    lazy var startMenuView: UIView = {
        EndlessStartView { [weak self] in
            self?.onStartRequested?()
        }
    }()
}
