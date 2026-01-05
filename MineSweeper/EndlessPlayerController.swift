import CoreGraphics

final class PlayerController {
    var position: CGPoint
    private(set) var hp: Int
    private(set) var maxHP: Int
    private let baseMoveSpeed: CGFloat

    var mineDamageMultiplier: CGFloat = 1.0
    var revealRadiusBonus: Int = 0
    var moveSpeedBonus: CGFloat = 0
    var itemDropRateBonus: CGFloat = 0

    private(set) var equipment: [ItemSlot: Item] = [:]
    private(set) var inventory: [Item] = []

    init(position: CGPoint, hp: Int = 6, moveSpeed: CGFloat = 120) {
        self.position = position
        self.hp = hp
        self.maxHP = hp
        self.baseMoveSpeed = moveSpeed
    }

    var moveSpeed: CGFloat {
        baseMoveSpeed * (1 + moveSpeedBonus)
    }

    func takeDamage(_ amount: Int) -> Bool {
        hp = max(0, hp - amount)
        return hp == 0
    }

    func heal(_ amount: Int) {
        hp = min(maxHP, hp + amount)
    }

    func apply(skill: Skill) {
        skill.apply(self)
    }

    func equip(item: Item) -> Item? {
        inventory.append(item)
        guard item.slot != .none else { return nil }

        if let equipped = equipment[item.slot], equipped.name == item.name {
            let combined = equipped.combined(with: item)
            equipment[item.slot] = combined
            return combined
        }

        if let equipped = equipment[item.slot], equipped.power >= item.power {
            return equipped
        }

        equipment[item.slot] = item
        return item
    }
}
