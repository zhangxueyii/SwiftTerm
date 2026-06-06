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

    @objc func toggleTouch (_ sender: UIButton) {
        terminalView?.allowMouseReporting.toggle()
        touchButton.isSelected = !(terminalView?.allowMouseReporting ?? false)
    }

    @objc func altLeftAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x62]) }
    @objc func altRightAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x66]) }
    @objc func homeAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x5B, 0x48]) }
    @objc func endAction (_ sender: AnyObject) { clickAndSend ([0x1B, 0x5B, 0x46]) }

    /**
     * This method setups the internal data structures to setup the UI shown on the accessory view,
     * if you provide your own implementation, you are responsible for adding all the elements to the
     * this view, and flagging some of the public properties declared here.
     */
    public func setupUI ()
    {
        for view in views {
            view.removeFromSuperview()
        }
        views = []
        terminalView?.setupKeyboardButtonColors()
        
        let savedOrder = UserDefaults.standard.stringArray(forKey: "accessory_key_order")
        let keyOrder = savedOrder ?? [
            "esc","ctrl","alt","tab",
            "tilde","colon","pipe","slash","dash",
            "f1","f2","f3","f4","f5","f6","f7","f8","f9","f10",
            "altLeft","altRight","home","end",
            "arrowLeft","arrowDown","arrowUp","arrowRight",
            "touch","keyboard"
        ]
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        stack.distribution = .fill
        
        let buttonWidth = CGFloat(UserDefaults.standard.object(forKey: "accessory_button_width") as? Double ?? 30)
        for keyId in keyOrder {
            if let button = buildButton(for: keyId) {
                button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
                stack.addArrangedSubview(button)
                views.append(button)
            }
        }
        
        scrollView.addSubview(stack)
        addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -4),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    func buildButton(for keyId: String) -> UIView? {
        switch keyId {
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
        b.backgroundColor = UIColor.white
        b.layer.borderWidth = 1.0
        b.layer.borderColor = UIColor.systemGray4.cgColor
        let pad = defaults.object(forKey: "accessory_padding") as? Double ?? 5
        b.contentEdgeInsets = UIEdgeInsets(top: pad, left: pad, bottom: pad, right: pad)
        
        let isMultiChar = title.count > 2 || title.hasPrefix("F")
        let fontSize: CGFloat
        if icon != "" {
            fontSize = defaults.object(forKey: "accessory_icon_size") as? Double ?? 12
        } else if isMultiChar {
            fontSize = defaults.object(forKey: "accessory_multi_char_font_size") as? Double ?? 11
        } else {
            fontSize = defaults.object(forKey: "accessory_single_char_font_size") as? Double ?? 12
        }
        b.titleLabel?.font = UIFont.systemFont(ofSize: useSmall ? max(fontSize - 1, 8) : fontSize)
        
        if icon != "" {
            let iconSize = defaults.object(forKey: "accessory_icon_size") as? Double ?? 12
            if let img = UIImage (systemName: icon, withConfiguration: UIImage.SymbolConfiguration (pointSize: iconSize)) {
                b.setImage(img.withTintColor(terminalView.buttonColor, renderingMode: .alwaysOriginal), for: .normal)
            }
        }
        return b
    }
    
    // I am not committed to this style, this is just something quick to get going
    static func styleButton (_ b: UIButton)
    {
        b.layer.cornerRadius = 5
        b.layer.masksToBounds = true
        b.layer.shadowOffset = CGSize(width: 0, height: 1.0)
        b.layer.shadowRadius = 0.0
        b.layer.shadowOpacity = 0.35
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
