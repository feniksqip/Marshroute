import UIKit

struct PeekAndPopData {
    weak var peekViewController: UIViewController?
    let popAction: (() -> ())
}