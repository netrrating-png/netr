import SwiftUI
import AVFoundation

struct LoopingVideoView: UIViewRepresentable {
    let fileName: String
    let fileExtension: String

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(fileName: fileName, fileExtension: fileExtension)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

class LoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    init(fileName: String, fileExtension: String) {
        super.init(frame: .zero)

        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else { return }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true

        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        queuePlayer = player

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        player.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
