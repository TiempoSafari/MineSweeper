import Foundation

enum RandomEventType: CaseIterable {
    case enemySpawn
    case challenge
    case reward
    case trap
}

struct RandomEvent {
    let type: RandomEventType
    let title: String
    let description: String
}

final class EventSystem {
    private let baseEventChance: Double = 0.22

    func rollEvent() -> RandomEvent? {
        guard Double.random(in: 0...1) < baseEventChance else { return nil }
        let type = RandomEventType.allCases.randomElement() ?? .reward
        switch type {
        case .enemySpawn:
            return RandomEvent(type: type, title: "敌人袭来", description: "出现了游荡的地雷怪！")
        case .challenge:
            return RandomEvent(type: type, title: "高风险挑战", description: "挑战成功将获得技能奖励。")
        case .reward:
            return RandomEvent(type: type, title: "补给点", description: "你发现了补给箱。")
        case .trap:
            return RandomEvent(type: type, title: "陷阱升级", description: "地雷威力暂时提高。")
        }
    }
}
