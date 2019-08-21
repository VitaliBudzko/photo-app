//
//  CollectionViewCell.swift
//  PhotoAlbum
//
//  Created by Budzko Vitali on 15.08.2019.
//  Copyright © 2019 BudzkoVitali. All rights reserved.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    func set(image: UIImage?) {
        imageView.image = image
        
        if image == nil {
            indicator.startAnimating()
        } else {
            indicator.stopAnimating()
        }
    }
}
