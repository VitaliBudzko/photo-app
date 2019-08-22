//
//  ViewController.swift
//  PhotoAlbum
//
//  Created by Budzko Vitali on 14.08.2019.
//  Copyright © 2019 Budzko Vitali. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, ImageTaskDownloadedDelegate {
    
    var imageTasks = [Int: ImageTask]()
    let localServerAddress = "http://192.168.0.40:3000"
    let picsumServerAddress = "https://picsum.photos"
    var picsumPosToImageIdMapper = [Int: Int]()
    var address = ""
    var totalImages = 0
    var firstImagesAmount = 0
    var secondImagesAmount = 0
    var total = 0
    var reloadAllButtonPressed = false
    var addButtonPressed = false
    
    let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .whiteLarge)
        ai.color = .black
        ai.translatesAutoresizingMaskIntoConstraints = false
        ai.startAnimating()
        return ai
    }()
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBAction func addButton(_ sender: Any) {
        addButtonPressed = true
        reloadAllButtonPressed = false
        changeImagesAmount()
    }
    
    @IBAction func reloadAll(_ sender: Any) {
        reloadAllButtonPressed = true
        addButtonPressed = false
       changeImagesAmount()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUsingPicsumServer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func imageDownloaded(position: Int) {
        self.collectionView?.reloadItems(at: [IndexPath(row: position, section: 0)])
    }
    
    func setupUsingPicsumServer() {
        address = picsumServerAddress

        guard let url = URL(string: "\(address)/list") else { return }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Error getting the total count: ", error)
                return
            }
            
            guard let data = data else { return }
            
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [[String: Any]] {
                print(responseJSON)
                // Skip first N pics
                let start = 10
                let count = responseJSON.count
                
                var pos = 0
                for i in start..<count {
                    guard let id = responseJSON[i]["id"] as? Int else { return }
                    self.picsumPosToImageIdMapper[pos] = id
                    pos += 1
                }
                
                self.finshedFetchingImagesInfo(totalImages: count - start)
            }
        }.resume()
    }
    
    func setupUsingLocalServer() {
        address = localServerAddress
        
        guard let url = URL(string: "\(address)/total") else { return }
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Error getting the total count: ", error)
                return
            }
            
            guard let data = data else { return }
            
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                guard let images = responseJSON["totalImages"] as? Int else { return }
                self.secondImagesAmount = images
                //self.finshedFetchingImagesInfo(totalImages: totalImages)
            }
        }.resume()
    }
    
    func changeImagesAmount() {
        if reloadAllButtonPressed {
            firstImagesAmount = 140
            total = firstImagesAmount
        }
        if addButtonPressed {
            total = secondImagesAmount
        }
        finshedFetchingImagesInfo(totalImages: total)
        collectionView.reloadData()
    }
    
    func finshedFetchingImagesInfo(totalImages: Int) {
        DispatchQueue.main.async {
            self.setupImageTasks(totalImages: totalImages)
            self.totalImages = totalImages
            self.collectionView?.reloadData()
            self.activityIndicator.stopAnimating()
        }
    }
    
    func setupImageTasks(totalImages: Int) {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        for i in 0..<totalImages {
            let url = URL(string: getImageUrlFor(pos: i))!
            let imageTask = ImageTask(position: i, url: url, session: session, delegate: self)
            imageTasks[i] = imageTask
        }
    }
    
    func getImageUrlFor(pos: Int) -> String {
        let isPicsum = address.contains("picsum")
        
        if isPicsum {
            let id = picsumPosToImageIdMapper[pos]!
    
            return "\(address)/id/\(id)/200/200/"
        }
        return "\(address)/image/\(pos)"
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        let pageWidth = self.view.frame.width - 30
        let proportionalOffset = collectionView.contentOffset.x / pageWidth
        _ = Int(round(proportionalOffset))
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Stop scrolling
        targetContentOffset.pointee = scrollView.contentOffset
        
        // Calculate conditions
        let pageWidth = self.view.frame.width - 30
        let collectionViewItemCount = 2000
        let proportionalOffset = collectionView.contentOffset.x / pageWidth
        let indexOfMajorCell = Int(round(proportionalOffset))
        let swipeVelocityThreshold: CGFloat = 0.5
        let indexOfCellBeforeDragging = Int(round(proportionalOffset))
        let hasEnoughVelocityToSlideToTheNextCell = indexOfCellBeforeDragging + 1 < collectionViewItemCount && velocity.x > swipeVelocityThreshold
        let hasEnoughVelocityToSlideToThePreviousCell = indexOfCellBeforeDragging - 1 >= 0 && velocity.x < -swipeVelocityThreshold
        let majorCellIsTheCellBeforeDragging = indexOfMajorCell == indexOfCellBeforeDragging
        let didUseSwipeToSkipCell = majorCellIsTheCellBeforeDragging && (hasEnoughVelocityToSlideToTheNextCell || hasEnoughVelocityToSlideToThePreviousCell)
        
        if didUseSwipeToSkipCell {
            // Animate so that swipe is just continued
            let snapToIndex = indexOfCellBeforeDragging + (hasEnoughVelocityToSlideToTheNextCell ? 1 : -1)
            let toValue = pageWidth * CGFloat(snapToIndex)
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: velocity.x,
                options: .allowUserInteraction,
                animations: {
                    scrollView.contentOffset = CGPoint(x: toValue, y: 0)
                    scrollView.layoutIfNeeded()
            },
                completion: nil
            )
        } else {
            // Pop back (against velocity)
            let indexPath = IndexPath(row: indexOfMajorCell, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .left, animated: true)
        }
    }
 
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalImages
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        imageTasks[indexPath.row]?.resume()
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        imageTasks[indexPath.row]?.pause()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! CollectionViewCell
        
        cell.imageView.makeBorders()
        
        let image = imageTasks[indexPath.row]?.image
        cell.set(image: image)
        
        return cell
    }
}

protocol ImageTaskDownloadedDelegate {
    func imageDownloaded(position: Int)
}

