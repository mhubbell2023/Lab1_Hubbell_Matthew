
import PhotosUI
import UIKit
import MapKit

class TaskDetailViewController: UIViewController, PHPickerViewControllerDelegate {

    @IBOutlet private weak var completedImageView: UIImageView!
    @IBOutlet private weak var completedLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var attachPhotoButton: UIButton!
    @IBOutlet weak var ViewPhotoButton: UIButton!
    
    // MapView outlet
    @IBOutlet private weak var mapView: MKMapView!

    var task: Task!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Register custom annotation view
        mapView.register(TaskAnnotationView.self, forAnnotationViewWithReuseIdentifier: TaskAnnotationView.identifier)

        // Set mapView delegate
        mapView.delegate = self

        // UI Candy
        mapView.layer.cornerRadius = 12

        updateUI()
        updateMapView()
    }
    
    // ADD THIS HERE ↓
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "PhotoSegue" {
            if let photoViewController = segue.destination as? PhotoViewController {
                photoViewController.task = task
                }
            }
        }
    /// Configure UI for the given task
    private func updateUI() {
        titleLabel.text = task.title
        descriptionLabel.text = task.description

        let completedImage = UIImage(
            systemName: task.isComplete ? "circle.inset.filled" : "circle"
        )

        completedImageView.image = completedImage?.withRenderingMode(.alwaysTemplate)
        completedLabel.text = task.isComplete ? "Complete" : "Incomplete"

        let color: UIColor = task.isComplete ? .systemBlue : .tertiaryLabel
        completedImageView.tintColor = color
        completedLabel.textColor = color

        mapView.isHidden = !task.isComplete
        attachPhotoButton.isHidden = task.isComplete
        ViewPhotoButton.isHidden = !task.isComplete    }

    @IBAction func didTapAttachPhotoButton(_ sender: Any) {

        if PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {

            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                switch status {

                case .authorized:
                    DispatchQueue.main.async {
                        self?.presentImagePicker()
                    }

                default:
                    DispatchQueue.main.async {
                        self?.presentGoToSettingsAlert()
                    }
                }
            }

        } else {
            presentImagePicker()
        }
    }

    private func presentImagePicker() {

        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())

        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)

        picker.delegate = self

        present(picker, animated: true)
    }

    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        // Dismiss the picker
        picker.dismiss(animated: true)

        // Get selected image
        let result = results.first

        // Get image location
        guard let assetId = result?.assetIdentifier,
              let location = PHAsset.fetchAssets(
                withLocalIdentifiers: [assetId],
                options: nil
              ).firstObject?.location else {
            return
        }

        print("📍 Image location coordinate: \(location.coordinate)")

        // Make sure we have an item provider
        guard let provider = result?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        // Load UIImage
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in

            if let error = error {
                DispatchQueue.main.async {
                    self?.showAlert(for: error)
                }
                return
            }

            guard let image = object as? UIImage else {
                return
            }

            print("🌉 We have an image!")

            DispatchQueue.main.async {

                // Set image and location on task
                self?.task.set(image, with: location)

                // Update UI
                self?.updateUI()

                // Update map
                self?.updateMapView()
            }
        }
    }

    func updateMapView() {
        // Make sure the task has image location.
        guard let imageLocation = task.imageLocation else { return }

        // Get the coordinate from the image location. This is the latitude / longitude of the location.
        // https://developer.apple.com/documentation/mapkit/mkmapview
        let coordinate = imageLocation.coordinate

        // Set the map view's region based on the coordinate of the image.
        // The span represents the maps's "zoom level". A smaller value yields a more "zoomed in" map area, while a larger value is more "zoomed out".
        let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        mapView.setRegion(region, animated: true)
        
        // Add an annotation to the map view based on image location.
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
}


// Helper methods
extension TaskDetailViewController {

    func presentGoToSettingsAlert() {

        let alertController = UIAlertController(
            title: "Photo Access Required",
            message: "In order to post a photo to complete a task, we need access to your photo library. You can allow access in Settings",
            preferredStyle: .alert
        )

        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in

            guard let settingsUrl = URL(
                string: UIApplication.openSettingsURLString
            ) else {
                return
            }

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }

        alertController.addAction(settingsAction)

        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: nil
        )

        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    func showAlert(for error: Error? = nil) {

        let alertController = UIAlertController(
            title: "Oops...",
            message: "\(error?.localizedDescription ?? "Please try again...")",
            preferredStyle: .alert
        )

        let action = UIAlertAction(title: "OK", style: .default)

        alertController.addAction(action)

        present(alertController, animated: true)
    }
}

extension TaskDetailViewController: MKMapViewDelegate {
    // Implement mapView(_:viewFor:) delegate method.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {

        // Dequeue the annotation view for the specified reuse identifier and annotation.
        // Cast the dequeued annotation view to your specific custom annotation view class, `TaskAnnotationView`
        // 💡 This is very similar to how we get and prepare cells for use in table views.
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: TaskAnnotationView.identifier, for: annotation) as? TaskAnnotationView else {
            fatalError("Unable to dequeue TaskAnnotationView")
        }

        // Configure the annotation view, passing in the task's image.
        annotationView.configure(with: task.image)
        return annotationView
    }
}

