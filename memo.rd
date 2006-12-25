To Do -- 優先順位の高い順


* Toolbar の localize -- Localized.strings はまだ

	
* FileTreeDataSource は invocation や view への instance 変数を保持しない方がいいと思う

* ファイルシステムの変更イベントを取得して、order.plist を更新する
	* 後回しにする。StationeryPalette が完成してから
	* 一時的に kqueue を停止する方法が必要
* order.plist を dictionary にする。
	* 日付情報を書き込むようにする
	* いらないかも・・・

* 表示してからでないと初期化できないのは苦しい
* メッセージのブラッシュアップ
* コードのブラッシュアップ

= 2006-12-25
* ひな形フラッグを外す
* LSUIElement を 1 にすると Finder で double click しても起動しない。
	* 解決
	*applicationShouldHandleReopen を使った

= 2006-12-24
* FileTreeView の root は NSAppcontroller が起動時に NSUserDefaults に書き込む
* basename を選択する。 -- あきらめる
* text field での拡張子の自動追加
* window がとじられたら、text field は Untitled にもどす。

= 2006-12-22
* file 名の履歴機能
* fileTreeView の選択項目の保存 -- item の開閉状態を記録する必要がある
	* index と名前を保存。一致したときのみ選択する
	* Binding で indexPathes を保存するようにしたが、再起動した時に反映されない
		* KeyedUnachivedFromDataTransformer を作った。
		* DataSource が読み込まれるタイミングはもっと後のようだ
	* Binding を使わずに手動でやるしかない。
	* indexPathes の保存
	* FileTreeNode に itemForIndexPath を実装
	
* 削除をしたときは、選択しない
* FileTreeView では、なぜか init がよばれない。
	* awakeFromNib で初期化する。
* double action による open
* alias file or symbolic link であるかどうかの check
* activate したら palette を表示するようにした。
* OK ボタンによるファイル生成機能
* resolving alias file
http://developer.apple.com/documentation/Cocoa/Conceptual/LowLevelFileMgmt/Tasks/ResolvingAliases.html

* OK ボタンによるファイル生成機能 -- file name の conflict の対応がまだ
* copy ボタンによるコピー
	* Finder を activate しない。
* file name の conflict のときは、save panel を開く
* alias の original をもとめる。


= 2006-12-21
* 保存場所 field への drag & drop -- NSBox を継承したクラスを作る必要があるようだ。
	* http://hmdt.jp/cocoaProg/AppKit/NSDragging/NSDragging.html
	* http://www.cocoadev.com/index.pl?DragAndDropWithNSViewSubclass
	* 枠のハイライトはあきらめる
	* カーソルが + マークになればいい
* 保存場所の取得
* window の位置保存、初回起動時のセンタリング
* replace, copy or move alert の localize
* Open panel をつかってファイルを登録する -- これは、controller の仕事か？

* Tool Bar をつくる
	* plus mark -- open dialog をひらいてファイルを追加
	* minus mark -- 選択項目をゴミ箱へ
	* folder plus mark -- folder を追加
	* open folder -- これはなくてもいいか。
	* rename 
	* reveal
	* help button
	* action を実装
	* 選択項目の有無で enable/disable を切り替える。-- FileTreeView に接続したら、自動的にそうなった
	
= 2006-12-20
* Toolbar の見た目はできた
* StationeryPalette の制作に移る

= 2006-12-19
* rootfolder を user defaults から読み込むようにする。
	* MainMenu.nib に全部収めていると、初期化のタイミングが確保できない。
	* window は nib を分離する。
* 新規フォルダ名のローカライズ
* FileTreeView 専用の localized resouce を用意する・・・やめ、nib のテキストを流用するように頑張る
* uniqueName の "copy" のローカライズ
* フォルダを追加する機能
* FileTreeController を FileTreeDataSource とする
* menu の action には first responder にしかつなげられない（respondToSelector でenable/disable を切り替える場合）
  起動時の接続に失敗してしまう。
  
= 2006-12-14
* FileTreeDataSouce は data source でいいのか？ delegate のほうがいいのかな？
 drag & drop は delegate か？もしそうなら、delegate にまわすことにする。
 いや data souce でよい
 
* 強制的に reload する method
	* OK
	* NDAlias は ファイルが存在しなくなると nil を返すようだ。

= 2006-12-13
* DragThing に drop した時、ファイルの参照がわたるようにしたい。
* Finder に同じファイル名があるときのエラー処理
* Finder へ drag &drop した時 -- NSDragOperationGeneric = 4
* ごみ箱にへ --NSDragOperationDelete  = 32,
* FileTreeView ないで移動 -- NSDragOperationMove    = 16,
* DragThing へ -- NSDragOperationGeneric = 4,
* FileTreeView ないでコピー -- NSDragOperationCopy    = 1,

* ゴミ箱への Drag & Drop 
	*  (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint
operation:(NSDragOperation)operation は - (NSArray *)outlineView:(NSTableView *)tv 
			namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination 
											forDraggedItems:(NSArray *)items 
	の後に呼ばれるみたいもっと前のイベントは？
	FileTreeView で namesOfPromisedFilesDroppedAtDestination を override
	ここで、source と destination をキャッシュして、
	draggedImage で実際の操作を実行するようにする。
	
* drag & drop でファイルを移動した時の data の relaod を最小限にする
	* FileTreeView 内での drag&drop に関しては済み
	* 外部からの Drag & drop はどうか？
* FileTreeView ないの drag&drop の処理を invocation を使った物に作り替える
* 重複ファイル名があるときのエラー表示
	* drag & drop で ファイルが追加されたときはどうか。
		* 一応、実装されている。
		* conflictErrorWindow を使うようにする
		* conflictErrowWindow は一つのときと複数のときで分ける必要がある。
			* 一つだけのときは、applyAllSwitch を deactive にする。
			* 置き換えないボタンを deactive にする。
* Drag & Drop でファイルが追加されたときの処理を作り替え中
	* 最初に、copy or move を聞く
			* conflict message はその後
	* 日本語を含むパスを copy できない -- うそ
	* 重複ファイル名があるときのエラー処理を未実装
		* - (NSString *)copyOrMoveFromPath:(NSString *)sourcePath 
							withSelector:(SEL)aSelector
							atIndex:(int *)indexPtr
							withReplacing:(BOOL)replaceFlag
		を使うようにする。

= 2006-12-12
* drag&drop 後にファイルの順番を入れ替えた後の選択項目がおかしい -- 済み
* drag&drop のコピーでコピー先が自動的に reload されない。 -- 済み

= 2006-12-11
* FileTreeView 内の移動で コンフリクトがある場合のエラー処理を実装 -- 済み
	* 現在の実装では、順番の入れ替えも移動と同じに扱ってしまっているかも -- 済み
* FileTreeView 内の drag&drop による移動を実装
* 重複ファイル名があるときのエラー表示
	* dupulicate の場合は OK
	* 異なる parent 間ではどうか。
* outline view 内でのコピーは名前を適当に変更して replace するかしないかは聞かない。
		* Finder の場合
			* "^0 のコピー"; -- 日本語環境
			* "^0 copy"; -- 英語環境
			* 拡張子の前に copy/のコピーが挿入されるようだ
			* 拡張子が無視される場合もある。例えば、".rd" 。
			* OS が知らない拡張子だとむしされるかしら
	* NSString の category として 
		* unique name 機能 --だいたいすみ
		* file test 機能 -- やめ

* rename の時に同じファイル名があるときのエラーメッセージを追加

= 2006-12-08
* コンテキストメニューの実装 -- 全部できた
	* Finder で表示 -- NSWorkspace が使えるらしい
	* relaod すべき parent node だけを relaod するようにする。
		* 複製の場合はすみ
		* rename , delete の場合も済み
		* delete と dupulicate は重複数コードがおおい。うまくまとめる
	* ゴミ箱に入れる -- だいたい済み
	* 複製 -- 済み
		* 複製した時に キャッシュの保存はまだしていない。--済み
	* 名前の変更
		editWithFrame:inView:editor:delegate:event:
		NSBroserCellだと、テキストの編集ができないようだ
		ImageAndTextCell に切り替える -- 済み
		cell のテキストの編集をpogramable に実行するにはどうすればいいのか？ -- editColumn
		編集の終了は delegate で受け取る。type search 機能で field editor の delegate とぶつかる。
		type search 機能は delegate を使わないで行えないか。 -- 済み
		escape キーで編集をキャンセルするには？ -- undo できるから気にしないことにする, abortEditing
		return キーで編集モードから抜け出すには？ -- 済み
* Finder のようにキータイプで選択項目を変更できるようにする --済み
	* fieldEditor の delegate は使わないですむかも -- 済み

= 2006.11.23
コンテキストメニューからの複製, 削除を実装

delegate には contextual menu のための respondToSelector は届かないようだ。
view のsubclass に実装するしかない。

= 2006.11.22
* Finder のようにキータイプで選択項目を変更できるようにする
	textDidChange から delegate に検索する文字列を送る。
	この方針はやめて、FileTreeView だけで閉じるようにした。
	
Finder のようにキータイプで選択項目を変更できるようにする
テキスト取得部分はできた。

find が始まっているかどうか。
	始まっている
		escape key event ならすべてリセット。fieldEditor に event を渡す。
		floating window が表示されているかどうか
			表示されている
				表示されていれば、すべてのキーボドイベントを capture
			表示されていない。
				下記の無視する event に該当するか
					該当する
						find 終了
					該当しない
						find 開始
						fieldEditor に keyevent を解釈させる前後の string をしらべる。
						変化がなければ、floating window が表示されていると解釈する。
			
	始まっていない。
		function key, command key, control key を含むときはむし。
		tab key を含むときは無視
		矢印キーの時は無視
		escape key event か
		上以外は、find を開始

floating window からの入力があったら、かならず reset する。		

NSTextInput Protcol を実装してもいいことはなかった。
* kEventTextInputShowHideBottomWindow に実装した handler がよばれない。
	* escape key をおすと呼ばれる。どうも期待している動作と違うみたい。
* TSMGetDocumentProperty input window の status が常に 0 になる。
	* TSM の状態を調べる関数とは違うようだ。

このアプローチはあきらめる。

= 2006.11.21
input window が使われているかどうか、調べるすべがなさそうだ。
  * kEventTextInputShowHideBottomWindow を install しても handler が実行されない。
  * TSMGetDocumentProperty で input window の status が常に 0 になる。
active な TSMDocument が存在しないからだろう
NSTexInputProtocol を つかって、inputWindow を表示させるか。
OSErr UseInputWindow (
   TSMDocumentID idocID,
   Boolean useWindow
);

NSTexInputProtocol を使った時に、TSMGetActiveDocument() が null にならなければ OK だ。

もしくは、文字列の keyEvent が送られてきているのに、fieldEditor の値が変わらないことにより、input window が表示されていると見なすか

前者の方が確実かも。input window を消すこと（escape key の event を field editor に送ればいいのか？）も必要

KeyDown -> inputText (CarbonEvent) -> textDidChange -> textDidEndEditing -> keyDown のおわり
interpretKeyEvents が一連の流れを生み出しているようだ

= 2006.11.15
* Finder から drop されたとき、root folder 以下に存在しないことを確認する
	* やらない。
	* source と destination が同じ場合は処理しない

* Finder から drop されたときは copy するか、移動するか聞く

* askCopyOrMoveDidEnd で NSFileManager への invoke がうまくいかない。
	* setSelector merhod で selector を設定する必要があったようだ。
	* すると、method signature をつかって、selector の設定はすんだものと思っていたが・・・
	* method signature とはなんぞや
	* MethodSignatureはメソッドの引数の数や型情報を表すオブジェクト
	* 終了

* Finder から drop されたとき同じ名前があるときの処理

* コピーするときはカーソールにプラスマーク
	* outline view ないで copy するときだけ（option key が押されているときだけ）表示する
		* plus cursor を表示するには SetThemeCursor(kThemeCopyArrowCursor);
		* plus cursor を消すタイミングを取得するには、NSOutlineView の sub class をつくる必要がありそう
		* なまえは FileTreeView にしよう。
		* 作った sub class で NSDraggingDestination Protocol の method を override する。
		* SetThemeCursor など使う必要はない。validateDrop で NSDragOperationCopy をかえせばいいようだ
		* Drag & Drop 中は - (void)flagsChanged:(NSEvent*)event の override が有効にならない
	* Finder へ drop するときは、常にコピー

* outline view 内でのDrag & Drop によるファイルのコピー

= 2006.11.14
* Finder への Drag & Drop
* Finder からの Drag & Drop を受け付ける

= 2006.11.02
* order の保存を実装

= 2006.11.01
Drag & Drop によるファイルの移動を実装（済み）

次にすること
* nodeDataに保存するファイル参照は path ではなく、alias にする。
	* NDAlias を使う。
	* NSURL+NDCarbonUtilities 内の FSpGetInfo をFSGetCatalogInfo に置き換えなければいけないようだ
		-> 終了　2006.11.02

= 2006.10.31
outlineview 内での drag&drop は実装できているようだ。
folder に移動した時に実際にファイルを移動する処理を考える。

 fileInfo　に相当する物を outline view の item とする
 icon は保存しない。
 icon 以外の情報を保存する。