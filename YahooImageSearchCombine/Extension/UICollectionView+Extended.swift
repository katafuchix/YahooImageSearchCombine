//
//  UICollectionView+Extended.swift
//  YahooImageSearchCombine
//
//  Created by cano on 2023/05/14.
//

import UIKit
import Combine

// MARK: Combline
extension UICollectionView {
    func items<Element>(
        _ builder: @escaping (UICollectionView, IndexPath, Element) -> UICollectionViewCell
    ) -> ([Element]) -> Void {
        let dataSource = CombineCollectionViewDataSource(builder: builder)
        return { items in
            dataSource.pushElements(items, to: self)
        }
    }
}

class CombineCollectionViewDataSource<Element>: NSObject, UICollectionViewDataSource {
    let build: (UICollectionView, IndexPath, Element) -> UICollectionViewCell
    var elements: [Element] = []

    init(builder: @escaping (UICollectionView, IndexPath, Element) -> UICollectionViewCell) {
        build = builder
        super.init()
    }

    func pushElements(_ elements: [Element], to collectionView: UICollectionView) {
        collectionView.dataSource = self
        self.elements = elements
        collectionView.reloadData()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        elements.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        build(collectionView, indexPath, elements[indexPath.row])
    }
}
