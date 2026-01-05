import Foundation

struct Skill: Equatable {
    let id: String
    let name: String
    let description: String
    let apply: (PlayerController) -> Void

    static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id
    }
}

final class SkillSystem {
    private let skillPool: [Skill]

    init() {
        skillPool = [
            Skill(id: "mine_shield", name: "抗爆护盾", description: "地雷伤害降低 30%") { player in
                player.mineDamageMultiplier *= 0.7
            },
            Skill(id: "reveal_eye", name: "探测镜片", description: "揭示半径 +1") { player in
                player.revealRadiusBonus += 1
            },
            Skill(id: "swift_feet", name: "轻盈步伐", description: "移动速度提高 20%") { player in
                player.moveSpeedBonus += 0.2
            },
            Skill(id: "lucky_charm", name: "幸运护符", description: "掉落率提高 25%") { player in
                player.itemDropRateBonus += 0.25
            },
            Skill(id: "heart_patch", name: "急救包", description: "立即回复 2 点生命") { player in
                player.heal(2)
            }
        ]
    }

    func randomSkills(count: Int) -> [Skill] {
        let shuffled = skillPool.shuffled()
        return Array(shuffled.prefix(min(count, shuffled.count)))
    }
}
