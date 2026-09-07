import UIKit

class PhotoViewController: UIViewController {

    @IBOutlet weak var photoView: UIImageView!

    var task: Task!

    override func viewDidLoad() {
        super.viewDidLoad()

        photoView.image = task.image
    }
}
