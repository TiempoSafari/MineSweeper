//
//  GameViewController.swift
//  MineSweeper
//
//  Created by 山枫 on 2026/1/3.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    private weak var gameScene: GameScene?
    private var startMenuView: UIVisualEffectView?
    private var dimmingView: UIVisualEffectView?
    private let difficulties: [DifficultyOption] = [
        DifficultyOption(title: "简单", rows: 8, cols: 8, mines: 10),
        DifficultyOption(title: "中等", rows: 12, cols: 10, mines: 20),
        DifficultyOption(title: "困难", rows: 16, cols: 12, mines: 35)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load 'GameScene.sks' as a GKScene. This provides gameplay related content
        // including entities and graphs.
        if let scene = GKScene(fileNamed: "GameScene") {
            
            // Get the SKScene from the loaded GKScene
            if let sceneNode = scene.rootNode as! GameScene? {
                
                // Copy gameplay related content over to the scene
                sceneNode.entities = scene.entities
                sceneNode.graphs = scene.graphs
                
                // Set the scale mode to scale to fit the window
                sceneNode.scaleMode = .aspectFill
                
                // Present the scene
                if let view = self.view as! SKView? {
                    view.presentScene(sceneNode)
                    
                    view.ignoresSiblingOrder = true
                    
                    view.showsFPS = true
                    view.showsNodeCount = true
                    gameScene = sceneNode
                    sceneNode.uiDelegate = self
                    configureStartMenu()
                }
            }
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

extension GameViewController {
    private func configureStartMenu() {
        guard let view = self.view else { return }

        let backdropEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let backdropView = UIVisualEffectView(effect: backdropEffect)
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.alpha = 0.7
        view.addSubview(backdropView)

        NSLayoutConstraint.activate([
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        dimmingView = backdropView

        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 28
        blurView.layer.masksToBounds = true
        blurView.layer.borderWidth = 1
        blurView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        blurView.backgroundColor = UIColor.white.withAlphaComponent(0.08)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "扫雷"
        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "选择难度开始游戏"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.textAlignment = .center

        let buttonStack = UIStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 12

        difficulties.forEach { difficulty in
            let button = glassButton(title: difficulty.title, action: #selector(startGame(_:)))
            button.accessibilityIdentifier = difficulty.title
            buttonStack.addArrangedSubview(button)
        }

        let containerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, buttonStack])
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.axis = .vertical
        containerStack.spacing = 16

        blurView.contentView.addSubview(containerStack)
        view.addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blurView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.78),

            containerStack.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 24),
            containerStack.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -24),
            containerStack.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 20),
            containerStack.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -20)
        ])

        startMenuView = blurView
    }

    private func glassButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.tintColor = UIColor.label
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func startGame(_ sender: UIButton) {
        guard let title = sender.title(for: .normal),
              let difficulty = difficulties.first(where: { $0.title == title }) else {
            return
        }
        gameScene?.startGame(rows: difficulty.rows, cols: difficulty.cols, mines: difficulty.mines)
        startMenuView?.isHidden = true
        dimmingView?.isHidden = true
    }
}

extension GameViewController: GameSceneDelegate {
    func gameSceneDidRequestStartMenu(_ scene: GameScene) {
        startMenuView?.isHidden = false
        dimmingView?.isHidden = false
    }

    func gameSceneDidStartGame(_ scene: GameScene) {
        startMenuView?.isHidden = true
        dimmingView?.isHidden = true
    }
}

private struct DifficultyOption {
    let title: String
    let rows: Int
    let cols: Int
    let mines: Int
}
