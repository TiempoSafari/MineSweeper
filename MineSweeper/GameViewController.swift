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
    private var backgroundImageView: UIImageView?
    private var difficultyTableView: UITableView?
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let backgroundImageView = backgroundImageView {
            backgroundImageView.image = makeBackgroundImage(size: view.bounds.size)
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

        let backgroundImage = UIImageView(image: makeBackgroundImage(size: view.bounds.size))
        backgroundImage.translatesAutoresizingMaskIntoConstraints = false
        backgroundImage.contentMode = .scaleAspectFill
        view.addSubview(backgroundImage)
        view.sendSubviewToBack(backgroundImage)

        NSLayoutConstraint.activate([
            backgroundImage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImage.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImage.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImage.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        backgroundImageView = backgroundImage

        let backdropEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let backdropView = UIVisualEffectView(effect: backdropEffect)
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.alpha = 0.65
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
        blurView.layer.cornerRadius = 30
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

        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = UIColor.clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 56
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DifficultyCell")
        difficultyTableView = tableView

        let containerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, tableView])
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
            containerStack.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -20),

            tableView.heightAnchor.constraint(equalToConstant: CGFloat(difficulties.count) * 58)
        ])

        startMenuView = blurView
    }
}

extension GameViewController: GameSceneDelegate {
    func gameSceneDidRequestStartMenu(_ scene: GameScene) {
        startMenuView?.isHidden = false
        dimmingView?.isHidden = false
        difficultyTableView?.isHidden = false
    }

    func gameSceneDidStartGame(_ scene: GameScene) {
        startMenuView?.isHidden = true
        dimmingView?.isHidden = true
        difficultyTableView?.isHidden = true
    }
}

extension GameViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        difficulties.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DifficultyCell", for: indexPath)
        let difficulty = difficulties[indexPath.row]
        var content = UIListContentConfiguration.cell()
        content.text = difficulty.title
        content.textProperties.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        content.textProperties.color = UIColor.label
        content.textProperties.alignment = .center
        cell.contentConfiguration = content

        var background = UIBackgroundConfiguration.clear()
        background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        background.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        background.strokeColor = UIColor.white.withAlphaComponent(0.25)
        background.strokeWidth = 1
        background.cornerRadius = 18
        cell.backgroundConfiguration = background
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let difficulty = difficulties[indexPath.row]
        gameScene?.startGame(rows: difficulty.rows, cols: difficulty.cols, mines: difficulty.mines)
        startMenuView?.isHidden = true
        dimmingView?.isHidden = true
        difficultyTableView?.isHidden = true
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

private extension GameViewController {
    func makeBackgroundImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let colors = [
                UIColor(red: 0.98, green: 0.65, blue: 0.2, alpha: 1).cgColor,
                UIColor(red: 0.32, green: 0.67, blue: 1.0, alpha: 1).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

            let circleColors = [
                UIColor(red: 1, green: 0.45, blue: 0.15, alpha: 0.9),
                UIColor(red: 0.2, green: 0.5, blue: 0.95, alpha: 0.8)
            ]
            for (index, color) in circleColors.enumerated() {
                let radius = min(size.width, size.height) * (index == 0 ? 0.35 : 0.25)
                let center = CGPoint(x: size.width * (index == 0 ? 0.2 : 0.85), y: size.height * (index == 0 ? 0.2 : 0.8))
                context.cgContext.setFillColor(color.cgColor)
                context.cgContext.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.cgContext.fillPath()
            }
        }
    }
}

private struct DifficultyOption {
    let title: String
    let rows: Int
    let cols: Int
    let mines: Int
}
