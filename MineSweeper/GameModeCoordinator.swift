import UIKit

enum GameModeKind {
    case traditional
    case challenge
    case endless
}

protocol GameModeCoordinating: AnyObject {
    var kind: GameModeKind { get }
    var title: String { get }
    var iconName: String { get }
    var startMenuView: UIView { get }

    func didSelect()
    func didDeselect()
    func resetSelection()
    func updateHUDForFlags(flagged: Int, mineCount: Int)
    func handleGameEnd(didWin: Bool)
}

extension GameModeCoordinating {
    func didSelect() {}
    func didDeselect() {}
    func resetSelection() {}
    func updateHUDForFlags(flagged: Int, mineCount: Int) {}
    func handleGameEnd(didWin: Bool) {}
}
