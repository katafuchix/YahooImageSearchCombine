//
//  ImageItemCell.swift
//  YahooImageSearchCombine
//
//  Created by cano on 2023/05/14.
//

import UIKit
import AlamofireImage

class ImageItemCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!

    func configure(_ url: URL) {
        self.clear()
        self.imageView.af_setImage(withURL: url)
    }
    
    func clear() {
        self.imageView.image = UIImage()
    }
}
