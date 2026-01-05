import Foundation

enum ItemSlot {
    case tool
    case armor
    case module
    case none
}

enum ItemRarity: CaseIterable {
    case common
    case rare
    case epic

    var displayName: String {
        switch self {
        case .common: return "普通"
        case .rare: return "稀有"
        case .epic: return "史诗"
        }
    }
}

struct Item: Equatable {
    let name: String
    let slot: ItemSlot
    let rarity: ItemRarity
    let power: Int
    let description: String

    func combined(with other: Item) -> Item {
        guard other.name == name else { return self }
        let newPower = power + max(1, other.power / 2)
        return Item(
            name: name,
            slot: slot,
            rarity: rarity,
            power: newPower,
            description: "\(description) · 叠加强化"
        )
    }
}
