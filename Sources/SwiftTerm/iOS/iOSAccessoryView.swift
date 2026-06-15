//
//  iOSAccessoryView.swift
//  
//  Implements an inputAccessoryView for the iOS terminal for common operations
//
//  Created by Miguel de Icaza on 5/9/20.
//
#if os(iOS) || os(visionOS)

import Foundation
import UIKit

/**
 * This class provides an input accessory for the terminal on iOS, you can access this via the `inputAccessoryView`
 * property in the `TerminalView` and casting the result to `TerminalAccessory`.
 *
 * This class surfaces some state that the terminal might want to poke at, you should at least support the following
 * properties;
 * `controlModifer` should be set if the control key is pressed
 */
public class TerminalAccessory: UIInputView, UIInputViewAudioFeedback {
    /// This points to an instanace of the `TerminalView` where events are sent
    public weak var terminalView: TerminalView?
    weak var terminal: Terminal?
    var controlButton: UIButton?
    var altButton: UIButton?
    /// This tracks whether the "control" button is turned on or not
    public var controlModifier: Bool = false {
        didSet {
            controlButton?.isSelected = controlModifier
        }
    }

    /// This tracks whether the "alt" button is turned on or not
    public var altModifier: Bool = false {
        didSet {
            altButton?.isSelected = altModifier
        }
    }
    
    var touchButton: UIButton!
    var overlayButton: UIButton?
    var hjklButton: UIButton?
    
    /// Called when the Commands key is tapped in the accessory bar.
    public var commandsHandler: (() -> Void)?
    
    /// Called when the Overlay toggle key is tapped in the accessory bar.
    public var overlayToggleHandler: (() -> Void)?
    
    /// Called when the HJKL toggle key is tapped (single tap).
    public var hjklHandler: (() -> Void)?
    
    /// Called when the HJKL key is double-tapped (toggle alt mode).
    public var hjklAltHandler: (() -> Void)?
    
    /// Tracks whether the overlay is currently shown; updates the button's selected state.
    public var showOverlay: Bool = false {
        didSet {
            overlayButton?.isSelected = showOverlay
        }
    }
    
    /// Tracks whether HJKL mode is on; updates the button's selected state.
    public var hjklModifier: Bool = false {
        didSet {
            hjklButton?.isSelected = hjklModifier
            updateHJKLKeyButtons()
        }
    }
    
    private var hjklTapWork: DispatchWorkItem?
    private var hjklKeyButtons: [UIButton] = []
    
    var views: [UIView] = []
    
    public init (frame: CGRect, inputViewStyle: UIInputView.Style, container: TerminalView)
    {
        self.terminalView = container
        self.terminal = terminalView?.getTerminal()
        super.init (frame: frame, inputViewStyle: inputViewStyle)
        allowsSelfSizing = true
    }
    
    public override var bounds: CGRect {
        didSet {
            setupUI ()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    #if os(iOS)
    // Override for UIInputViewAudioFeedback
    public var enableInputClicksWhenVisible: Bool { true }
    #endif
    
    func clickAndSend (_ data: [UInt8])
    {
        #if os(iOS)
        UIDevice.current.playInputClick()
        #endif
        terminalView?.send (data)
    }

    func clickAndInsertText (_ text: String)
    {
        #if os(iOS)
        UIDevice.current.playInputClick()
        #endif
        terminalView?.insertTextFromAccessory(text)
    }
    
    @objc func commandsAction (_ sender: AnyObject) {
        commandsHandler? ()
    }

    @objc func esc (_ sender: AnyObject) { clickAndSend ([0x1b]) }
    @objc func tab (_ sender: AnyObject) { clickAndSend ([0x9]) }
    @objc func tilde (_ sender: AnyObject) { clickAndInsertText ("~") }
    @objc func pipe (_ sender: AnyObject) { clickAndInsertText ("|") }
    @objc func colon (_ sender: AnyObject) { clickAndInsertText (":") }
    @objc func slash (_ sender: AnyObject) { clickAndInsertText ("/") }
    @objc func dash (_ sender: AnyObject) { clickAndInsertText ("-") }
    @objc func f1 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[0]) }
    @objc func f2 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[1]) }
    @objc func f3 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[2]) }
    @objc func f4 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[3]) }
    @objc func f5 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[4]) }
    @objc func f6 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[5]) }
    @objc func f7 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[6]) }
    @objc func f8 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[7]) }
    @objc func f9 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[8]) }
    @objc func f10 (_ sender: AnyObject) { clickAndSend (EscapeSequences.cmdF[9]) }
    
    @objc
    func ctrl (_ sender: UIButton)
    {
        controlModifier.toggle()
    }

    @objc
    func alt (_ sender: UIButton)
    {
        altModifier.toggle()
        terminalView?.metaModifier = altModifier
    }

    // Controls the timer for auto-repeat
    var repeatCommand: (() -> ())? = nil
    var repeatTimer: Timer?
    var repeatTask: Task<(), Never>?
    
    func startTimerForKeypress (repeatKey: @escaping () -> ())
    {
        repeatKey ()
        repeatCommand = repeatKey
        
        repeatTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !(repeatTask?.isCancelled ?? true) else { return }
            let rc = self.repeatCommand
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                rc? ()
            }
        }
    }
    
    @objc
    func cancelTimer ()
    {
        repeatTimer?.invalidate()
        repeatCommand = nil
        repeatTimer = nil
        repeatTask?.cancel()
    }
    
    @objc func up (_ sender: UIButton)
    {
        startTimerForKeypress { self.terminalView?.sendKeyUp () }
    }
    
    @objc func down (_ sender: UIButton)
    {
        startTimerForKeypress { self.terminalView?.sendKeyDown () }
    }
    
    @objc func left (_ sender: UIButton)
    {
        startTimerForKeypress { self.terminalView?.sendKeyLeft() }
    }
    
    @objc func right (_ sender: UIButton)
    {
        startTimerForKeypress { self.terminalView?.sendKeyRight() }
    }


    @objc func toggleInputKeyboard (_ sender: UIButton) {
        #if os(iOS)
        UIDevice.current.playInputClick()
        #endif
        guard let tv = terminalView else { return }

        if tv.inputView == nil {
            #if os(visionOS)
            tv.inputView = KeyboardView (frame: CGRect (origin: CGPoint.zero,
                                                        size: CGSize (width: 300,
                                                                      height: 400)),
                                         terminalView: terminalView)
            #else
            tv.inputView = KeyboardView (frame: CGRect (origin: CGPoint.zero,
                                                        size: CGSize (width: UIScreen.main.bounds.width,
                                                                      height: max((UIScreen.main.bounds.height / 5),140))),
                                         terminalView: terminalView)
            #endif
        } else {
            tv.inputView = nil
        }
        UIView.performWithoutAnimation {
            tv.reloadInputViews()
        }
    }

    @objc func overlayToggleAction (_ sender: AnyObject) {
        overlayToggleHandler? ()
    }

    @objc func hjklAction (_ sender: AnyObject) {
        if let w = hjklTapWork {
            w.cancel()
            hjklTapWork = nil
            hjklAltHandler? ()
        } else {
            hjklTapWork = DispatchWorkItem { [weak self] in
                self?.hjklHandler? ()
            }
            if let w = hjklTapWork {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: w)
            }
        }
    }

    @objc func hjklKeyAction (_ sender: AnyObject) {
        guard let btn = sender as? UIButton else { return }
        if hjklModifier {
            switch btn.tag {
            case 0: clickAndSend([0x1b, 0x5b, 0x44]) // h → left
            case 1: clickAndSend([0x1b, 0x5b, 0x42]) // j → down
            case 2: clickAndSend([0x1b, 0x5b, 0x41]) // k → up
            case 3: clickAndSend([0x1b, 0x5b, 0x43]) // l → right
            default: break
            }
        } else {
            let chars: [UInt8] = [0x68, 0x6a, 0x6b, 0x6c] // h, j, k, l
            guard btn.tag >= 0 && btn.tag < 4 else { return }
            clickAndSend([chars[btn.tag]])
        }
    }

    private func updateHJKLKeyButtons() {
        let icons = ["arrow.left", "arrow.down", "arrow.up", "arrow.right"]
        let titles = ["h", "j", "k", "l"]
        for btn in hjklKeyButtons {
            let idx = btn.tag
            guard idx >= 0 && idx < 4 else { continue }
            if hjklModifier {
                btn.setTitle("", for: .normal)
                let iconSize = UserDefaults.standard.object(forKey: "accessory_icon_size") as? Double ?? 9
                if let img = UIImage(systemName: icons[idx], withConfiguration: UIImage.SymbolConfiguration(pointSize: iconSize)) {
                    btn.setImage(img.withTintColor(terminalView?.buttonColor ?? .darkGray, renderingMode: .alwaysOriginal), for: .normal)
                }
            } else {
                btn.setImage(nil, for: .normal)
                btn.setTitle(titles[idx], for: .normal)
            }
        }
    }

    @objc func toggleTouch (_ sender: UIButton) {
        terminalView?.allowMouseReporting.toggle()
        touchButton.isSelected = !(terminalView?.allowMouseReporting ?? false)
    }

    @objc func altLeftAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x62]) }
    @objc func altRightAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x66]) }
    @objc func homeAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x5B, 0x48]) }
    @objc func endAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x5B, 0x46]) }
    @objc func altEnterAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x0D]) }
    @objc func ctrlCAction (_ sender: AnyObject) { clickAndSend ([0x03]) }

    /**
     * This method setups the internal data structures to setup the UI shown on the accessory view,
     * if you provide your own implementation, you are responsible for adding all the elements to the
     * this view, and flagging some of the public properties declared here.
     */
    /// Force a full UI rebuild from UserDefaults settings.
    /// Call this after changing accessory key order, second row visibility, etc.
    public func refreshUI ()
    {
        setupUI()
    }

    public func setupUI ()
    {
        for view in views {
            view.removeFromSuperview()
        }
        views = []
        terminalView?.setupKeyboardButtonColors()
        
        let savedOrder = UserDefaults.standard.stringArray(forKey: "accessory_key_order")
        let keyOrder = savedOrder ?? [
            "commands","esc","altEnter","ctrlC","ctrl","alt","tab",
            "tilde","colon","pipe","slash","dash",
            "f1","f2","f3","f4","f5","f6","f7","f8","f9","f10",
            "altLeft","altRight","home","end",
            "touch","keyboard"
        ]
        
        let buttonWidth = CGFloat(UserDefaults.standard.object(forKey: "accessory_button_width") as? Double ?? 26)
        
        let showSecondRow = UserDefaults.standard.object(forKey: "show_second_row") as? Bool ?? true
        let savedSecondOrder = UserDefaults.standard.stringArray(forKey: "accessory_second_row_order")
        let secondKeyIds = savedSecondOrder ?? [
            "tab",
            "arrowLeft", "arrowDown", "arrowUp", "arrowRight",
            "altLeft", "altRight", "home", "end"
        ]
        
        // Top row: configurable accessory keys
        let topScrollView = UIScrollView()
        topScrollView.translatesAutoresizingMaskIntoConstraints = false
        topScrollView.showsHorizontalScrollIndicator = false
        
        let topStack = UIStackView()
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.axis = .horizontal
        topStack.spacing = 2
        topStack.alignment = .center
        topStack.distribution = .fill
        
        for keyId in keyOrder {
            if let button = buildButton(for: keyId) {
                button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
                button.heightAnchor.constraint(equalToConstant: buttonWidth).isActive = true
                topStack.addArrangedSubview(button)
                views.append(button)
            }
        }
        
        topScrollView.addSubview(topStack)
        
        if showSecondRow {
            // Bottom row: configurable second row keys
            let bottomScrollView = UIScrollView()
            bottomScrollView.translatesAutoresizingMaskIntoConstraints = false
            bottomScrollView.showsHorizontalScrollIndicator = false
            
            let bottomStack = UIStackView()
            bottomStack.translatesAutoresizingMaskIntoConstraints = false
            bottomStack.axis = .horizontal
            bottomStack.spacing = 2
            bottomStack.alignment = .center
            bottomStack.distribution = .fill
            
            for keyId in secondKeyIds {
                if let button = buildButton(for: keyId) {
                    button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
                    button.heightAnchor.constraint(equalToConstant: buttonWidth).isActive = true
                    bottomStack.addArrangedSubview(button)
                    views.append(button)
                }
            }
            
            bottomScrollView.addSubview(bottomStack)
            
            let verticalStack = UIStackView()
            verticalStack.translatesAutoresizingMaskIntoConstraints = false
            verticalStack.axis = .vertical
            verticalStack.spacing = 2
            verticalStack.distribution = .fill
            
            verticalStack.addArrangedSubview(topScrollView)
            verticalStack.addArrangedSubview(bottomScrollView)
            
            addSubview(verticalStack)
            
            NSLayoutConstraint.activate([
                verticalStack.topAnchor.constraint(equalTo: topAnchor),
                verticalStack.bottomAnchor.constraint(equalTo: bottomAnchor),
                verticalStack.leadingAnchor.constraint(equalTo: leadingAnchor),
                verticalStack.trailingAnchor.constraint(equalTo: trailingAnchor),
                
                topStack.topAnchor.constraint(equalTo: topScrollView.topAnchor),
                topStack.bottomAnchor.constraint(equalTo: topScrollView.bottomAnchor),
                topStack.leadingAnchor.constraint(equalTo: topScrollView.leadingAnchor, constant: 4),
                topStack.trailingAnchor.constraint(equalTo: topScrollView.trailingAnchor, constant: -4),
                topStack.heightAnchor.constraint(equalTo: topScrollView.heightAnchor),
                
                bottomStack.topAnchor.constraint(equalTo: bottomScrollView.topAnchor),
                bottomStack.bottomAnchor.constraint(equalTo: bottomScrollView.bottomAnchor),
                bottomStack.leadingAnchor.constraint(equalTo: bottomScrollView.leadingAnchor, constant: 4),
                bottomStack.trailingAnchor.constraint(equalTo: bottomScrollView.trailingAnchor, constant: -4),
                bottomStack.heightAnchor.constraint(equalTo: bottomScrollView.heightAnchor),
            ])
        } else {
            addSubview(topScrollView)
            NSLayoutConstraint.activate([
                topScrollView.topAnchor.constraint(equalTo: topAnchor),
                topScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
                topScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                topScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                topStack.topAnchor.constraint(equalTo: topScrollView.topAnchor),
                topStack.bottomAnchor.constraint(equalTo: topScrollView.bottomAnchor),
                topStack.leadingAnchor.constraint(equalTo: topScrollView.leadingAnchor, constant: 4),
                topStack.trailingAnchor.constraint(equalTo: topScrollView.trailingAnchor, constant: -4),
                topStack.heightAnchor.constraint(equalTo: topScrollView.heightAnchor),
            ])
        }
    }

    func buildButton(for keyId: String) -> UIView? {
        switch keyId {
        case "commands":
            return makeButton("", #selector(commandsAction), icon: "terminal", isNormal: false)
        case "overlay":
            let btn = makeButton("", #selector(overlayToggleAction), icon: "rectangle.on.rectangle", isNormal: false)
            overlayButton = btn
            return btn
        case "hjkl":
            let btn = makeButton("hjkl", #selector(hjklAction), isNormal: false)
            hjklButton = btn
            return btn
        case "hjklH":
            let btn = makeButton("h", #selector(hjklKeyAction), isNormal: false)
            btn.tag = 0
            hjklKeyButtons.append(btn)
            return btn
        case "hjklJ":
            let btn = makeButton("j", #selector(hjklKeyAction), isNormal: false)
            btn.tag = 1
            hjklKeyButtons.append(btn)
            return btn
        case "hjklK":
            let btn = makeButton("k", #selector(hjklKeyAction), isNormal: false)
            btn.tag = 2
            hjklKeyButtons.append(btn)
            return btn
        case "hjklL":
            let btn = makeButton("l", #selector(hjklKeyAction), isNormal: false)
            btn.tag = 3
            hjklKeyButtons.append(btn)
            return btn
        case "esc":
            return makeButton("⎋", #selector(esc), isNormal: false)
        case "ctrl":
            let b = makeButton("^", #selector(ctrl), isNormal: false)
            controlButton = b
            return b
        case "alt":
            let b = makeButton("⌥", #selector(alt), isNormal: false)
            altButton = b
            return b
        case "tab":
            return makeButton("⇥", #selector(tab), isNormal: false)
        case "tilde":
            return makeButton("~", #selector(tilde))
        case "colon":
            return makeButton(":", #selector(colon))
        case "pipe":
            return makeButton("|", #selector(pipe))
        case "slash":
            return makeButton("/", #selector(slash))
        case "dash":
            return makeButton("-", #selector(dash))
        case "arrowLeft":
            return makeAutoRepeatButton("arrow.left", #selector(left))
        case "arrowDown":
            return makeAutoRepeatButton("arrow.down", #selector(down))
        case "arrowUp":
            return makeAutoRepeatButton("arrow.up", #selector(up))
        case "arrowRight":
            return makeAutoRepeatButton("arrow.right", #selector(right))
        case "touch":
            let b = makeButton("", #selector(toggleTouch), icon: "hand.draw", isNormal: false)
            b.isSelected = terminalView?.allowMouseReporting ?? false
            touchButton = b
            return b
        case "keyboard":
            return makeButton("", #selector(toggleInputKeyboard), icon: "keyboard.chevron.compact.down", isNormal: false)
        case "altLeft":
            return makeButton("◁", #selector(altLeftAction))
        case "altRight":
            return makeButton("▷", #selector(altRightAction))
        case "home":
            return makeButton("↖", #selector(homeAction))
        case "end":
            return makeButton("↘", #selector(endAction))
        case "altEnter":
            return makeButton("↩", #selector(altEnterAction))
        case "ctrlC":
            return makeButton("^C", #selector(ctrlCAction))
        case "f1": return makeButton("F1", #selector(f1))
        case "f2": return makeButton("F2", #selector(f2))
        case "f3": return makeButton("F3", #selector(f3))
        case "f4": return makeButton("F4", #selector(f4))
        case "f5": return makeButton("F5", #selector(f5))
        case "f6": return makeButton("F6", #selector(f6))
        case "f7": return makeButton("F7", #selector(f7))
        case "f8": return makeButton("F8", #selector(f8))
        case "f9": return makeButton("F9", #selector(f9))
        case "f10": return makeButton("F10", #selector(f10))
        default:
            return nil
        }
    }

    var _useSmall: Bool {
        frame.width < 380
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    func makeAutoRepeatButton (_ iconName: String, _ action: Selector) -> UIButton
    {
        let b = makeButton ("", action, icon: iconName)
        b.addTarget(self, action: #selector(cancelTimer), for: .touchUpOutside)
        b.addTarget(self, action: #selector(cancelTimer), for: .touchCancel)
        b.addTarget(self, action: #selector(cancelTimer), for: .touchUpInside)
        return b
    }
    
    func makeButton (_ title: String, _ action: Selector, icon: String = "", isNormal: Bool = true) -> UIButton
    {
        let useSmall = self._useSmall
        let b = BackgroundSelectedButton.init(type: .roundedRect)
        let defaults = UserDefaults.standard
        
        TerminalAccessory.styleButton (b)
        b.addTarget(self, action: action, for: .touchDown)
        b.setTitle(title, for: .normal)
        guard let terminalView else {
            return b
        }
        b.color = UIColor.white
        b.setTitleColor(UIColor.darkGray, for: .normal)
        b.setTitleColor(UIColor.darkGray, for: .selected)
        let useThemeBg = defaults.object(forKey: "accessory_use_theme_background") as? Bool ?? true
        let bgColor: UIColor
        if useThemeBg {
            bgColor = terminalView.buttonBackgroundColor
        } else if let bgData = defaults.object(forKey: "accessory_background_color_data") as? Data,
                  let storedColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: bgData) {
            bgColor = storedColor
        } else {
            bgColor = UIColor.white
        }
        b.backgroundColor = bgColor
        b.color = bgColor
        b.layer.borderWidth = 1.0
        b.layer.borderColor = UIColor.systemGray4.cgColor
        let pad = defaults.object(forKey: "accessory_padding") as? Double ?? 3
        b.contentEdgeInsets = UIEdgeInsets(top: pad, left: pad, bottom: pad, right: pad)
        
        let isMultiChar = title.count > 2 || title.hasPrefix("F")
        let fontSize: CGFloat
        if icon != "" {
            fontSize = defaults.object(forKey: "accessory_icon_size") as? Double ?? 9
        } else if isMultiChar {
            fontSize = defaults.object(forKey: "accessory_multi_char_font_size") as? Double ?? 9
        } else {
            fontSize = defaults.object(forKey: "accessory_single_char_font_size") as? Double ?? 12
        }
        b.titleLabel?.font = UIFont.systemFont(ofSize: useSmall ? max(fontSize - 1, 8) : fontSize)
        
        if icon != "" {
            let iconSize = defaults.object(forKey: "accessory_icon_size") as? Double ?? 9
            if let img = UIImage (systemName: icon, withConfiguration: UIImage.SymbolConfiguration (pointSize: iconSize)) {
                b.setImage(img.withTintColor(terminalView.buttonColor, renderingMode: .alwaysOriginal), for: .normal)
            }
        }
        return b
    }
    
    // I am not committed to this style, this is just something quick to get going
    static func styleButton (_ b: UIButton)
    {
        let defaults = UserDefaults.standard
        b.layer.cornerRadius = defaults.object(forKey: "accessory_corner_radius") as? Double ?? 5
        let shadowEnabled = defaults.object(forKey: "accessory_shadow_enabled") as? Bool ?? true
        if shadowEnabled {
            b.layer.masksToBounds = false
            b.layer.shadowOffset = CGSize(width: 0, height: 1.0)
            b.layer.shadowRadius = 0.0
            b.layer.shadowOpacity = Float(defaults.object(forKey: "accessory_shadow_opacity") as? Double ?? 0.10)
        } else {
            b.layer.masksToBounds = true
            b.layer.shadowOpacity = 0
        }
    }
}


class BackgroundSelectedButton: UIButton {
    
    var color: UIColor?
    
    override var isSelected: Bool {
        didSet {
            self.backgroundColor = isSelected ? UIView().tintColor : color
        }
    }
}
#endif
