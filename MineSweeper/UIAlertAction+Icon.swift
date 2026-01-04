import UIKit

extension UIAlertAction {
    /// 通过 KVC 为 UIAlertAction 注入系统图标（非公开 API）。
    func setSystemIcon(_ image: UIImage?) {
        setValue(image, forKey: "image")
    }
}
