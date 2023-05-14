//
//  ViewController.swift
//  YahooImageSearchCombine
//
//  Created by cano on 2023/05/14.
//

import UIKit
import Combine
import CombineCocoa

class ViewController: UIViewController {

    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    private let viewModel = ViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.setUpView()
        self.bind()
    }
    
    func setUpView() {
        self.collectionView.delegate = self
    }
    
    func bind() {
        // 検索キーワード
        self.textField
            .textPublisher // AnyPublisher<String?, Never>
            .compactMap { $0 } // nilを処理したくないのでcompactMapを使ってnilを除去
            .sink { [weak self] text in
                self?.viewModel.searchWord = text
            }
            .store(in: &cancellables)
        
        // 検索ボタン押下可能
        self.viewModel.$isSearchButtonEnabled
            .sink(receiveValue: { [weak self] bool in
                self?.searchButton.isEnabled = bool
            })
            .store(in: &cancellables)
        
        // 検索ボタン
        self.searchButton.tapPublisher
            .sink(receiveValue: { [weak self] _ in
                self?.viewModel.inputs.searchTrigger.send(())
            })
            .store(in: &cancellables)
        
        // 検索結果
        self.viewModel.$items
            .sink(receiveValue: collectionView.items { collectionView, indexPath, element in
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageItemCell", for: indexPath) as! ImageItemCell
                cell.clear()
                if let url = URL(string: element) {
                    cell.configure(url)
                }
                return cell
            })
            .store(in: &cancellables)
        
        // ローディング
        self.viewModel.$isLoading.sink(receiveValue:{ [weak self] bool in
                if bool {
                    self?.indicator.startAnimating()
                } else {
                    self?.indicator.stopAnimating()
                }
            })
            .store(in: &cancellables)
        
        // エラー
        self.viewModel.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                let alert = UIAlertController(
                    title: "エラー",
                    message: error.localizedDescription,
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
            .store(in: &cancellables)
    }
}

// 画像ビューワーで検索結果の画像をスライド表示
extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
         let photos: [SKPhoto] = self.viewModel.outputs.values.value
            .compactMap { return SKPhoto.photoWithImageURL($0) }
        
         let browser = SKPhotoBrowser(photos: photos)
         browser.initializePageIndex(indexPath.row)
         self.present(browser, animated: true, completion: {})
    }
}
