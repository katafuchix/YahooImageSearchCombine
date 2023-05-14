//
//  ViewModel.swift
//  YahooImageSearchCombine
//
//  Created by cano on 2023/05/14.
//

import Foundation
import Combine

protocol ViewModelInputs {
    // 検索キーワード
    var searchWord: String { get }
    // 検索トリガ
    var searchTrigger: PassthroughSubject<Void, Never> { get }
}

protocol ViewModelOutputs {
    // 検索結果
    var items: [String] { get }
    var values: CurrentValueSubject<[String], Never> { get }
    
    // 検索ボタンの押下可否
    var isSearchButtonEnabled: Bool { get }
    // 検索中か
    var isLoading: Bool { get }
    // エラー
    var error: Error? { get }
}

protocol ViewModelType {
    var inputs: ViewModelInputs { get }
    var outputs: ViewModelOutputs { get }
}

class ViewModel: ObservableObject, ViewModelType, ViewModelInputs, ViewModelOutputs {
    
    // MARK: - Properties
    var inputs: ViewModelInputs { return self }
    var outputs: ViewModelOutputs { return self }
    
    // MARK: - Input
    // 検索キーワード
    @Published var searchWord: String = ""
    // 検索トリガ
    @Published var searchTrigger: PassthroughSubject<Void, Never> = PassthroughSubject<Void, Never>()
    
    // MARK: - Output
    // 検索結果
    @Published var items: [String] = []
    @Published var values = CurrentValueSubject<[String], Never>([])
    // 検索ボタンの押下可否
    @Published var isSearchButtonEnabled: Bool = false
    // 検索中か
    @Published var isLoading: Bool = false
    // エラー
    @Published var error: Error? = nil
    
    // MARK: - Private
    // searchWordの値を受ける
    private let searchSubject = PassthroughSubject<String, Never>()
    
    // searchSubjectに値がくると処理が走る
    private var searchPublisher: AnyPublisher<String, Never> {
        return searchSubject.eraseToAnyPublisher()
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 検索トリガ起動
        self.searchTrigger
            .sink { [weak self] _ in
                guard let searchText = self?.searchWord else { return }
                self?.searchSubject.send(searchText)
            }
            .store(in: &cancellables)
        
        // searchSubjectから呼ばれる検索処理
        searchPublisher
            // flatMapの後にはAnyPublisher<T, Never>の型を返す必要があります。
            //これにより、エラーハンドリングなどでエラーをキャッチして処理することができ、ストリームが正常に継続して流れるようになります。
            // Result型で返す
            .flatMap { searchText -> AnyPublisher<Result<[String], Error>, Never> in
                self.isLoading = true
                // ネットワークリクエストなどの非同期処理を行うPublisherを返す
                return self.searchAction(query: searchText)
                    .map { Result<[String], Error>.success($0) }
                    .catch { Just(Result<[String], Error>.failure($0)) }
                    .eraseToAnyPublisher()
            }
            .sink(receiveValue: { result in
                switch result {
                case .success(let response):
                    // 成功時の処理
                    self.isLoading = false
                    self.items = response
                    self.values.send(self.items)
                    //print("Received search response: \(response)")
                case .failure(let error):
                    // エラー時の処理
                    //print("Search failed with error: \(error)")
                    self.isLoading = false
                    //self.showErrorAlert = true
                    self.error = error
                }
            })
            .store(in: &cancellables)
        
        self.$searchWord.sink(receiveValue: { [weak self] text in
            self?.isSearchButtonEnabled = text.count >= 3
        })
        .store(in: &cancellables)
    }
    
    // flatMapのクロージャ内で明示的に 戻り値の型 AnyPublisher<[String], Never> を指定しないと
    // Type of expression is ambiguous without more context　のエラーがでます
    func searchAction(query: String) -> AnyPublisher<[String], Error> {
        // Yahoo画像検索
        let urlStr =  "https://search.yahoo.co.jp/image/search?ei=UTF-8&p=\(query)"
        let url = URL(string:urlStr.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!)!

        // User-Agentに自分のメールアドレスをセットしておく
        var request = URLRequest(url: url)
        request.addValue(Constants.mail, forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
          .map(\.data)
          .map { String(data: $0, encoding: .utf8) }
          .map { $0! }
          .compactMap { str in
              let pattern = "(https?)://msp.c.yimg.jp/([A-Z0-9a-z._%+-/]{2,1024}).jpg"
              let regex = try! NSRegularExpression(pattern: pattern, options: [])
              let results = regex.matches(in: str, options: [], range: NSRange(0..<str.count))
              
              return results.map { result in
                  let start = str.index(str.startIndex, offsetBy: result.range(at: 0).location)
                  let end = str.index(start, offsetBy: result.range(at: 0).length)
                  let text = String(str[start..<end])
                  return text
              }.reduce([], { $0.contains($1) ? $0 : $0 + [$1] })
          }
          .receive(on: DispatchQueue.main) // メインスレッドで値の発行を行う
          .mapError { error -> Error in
                      return error
                  }
          .eraseToAnyPublisher()
    }
}
