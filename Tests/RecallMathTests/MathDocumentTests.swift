import SwiftUI
@_spi(Textual) import SwiftUIMath
import Testing

@testable import RecallMath

@Test func mixedMathKeepsProseAndDisplayBoundaries() {
    let document = MathDocument(#"Differentiate \(e^{g(x)}\).\[e^{g(x)}g'(x)\]"#)
    #expect(
        document.parts == [
            .text("Differentiate "), .formula("e^{g(x)}", display: false), .text("."),
            .formula("e^{g(x)}g'(x)", display: true),
        ])
}

@Test func incompleteDelimitersAndMarkupStayLiteral() {
    let text = #"<script>alert(1)</script> and \(unfinished"#
    #expect(MathDocument(text).parts == [.text(text)])
    #expect(MathDocument("").parts.isEmpty)
}

@Test func voiceOverReadsNestedFractionsAndChainRule() {
    #expect(
        MathSpeech.read(#"\frac{1-x\ln 2}{2^x}"#)
            == "fraction 1 minus x natural log 2 over 2 to the power x end power end fraction")
    #expect(
        MathSpeech.read(#"e^{g(x)}g^{\prime}(x)"#)
            == "e to the power g(x) end power g prime (x)")
}

@Test func nativeMathHandlesUnarySignsAcrossSpacingAndExistingSetSymbols() {
    let font = Math.Font(name: .latinModern, size: 24)
    for latex in [#"\cos x,\quad-\sin x,\quad-\cos x,\quad\sin x"#, #"\varnothing"#, #"3\nmid19"#] {
        let bounds = Math.typographicBounds(for: latex, fitting: .unspecified, font: font, style: .display)
        #expect(bounds.width > 0)
        #expect(bounds.size.height > 0)
    }
    let unsupported = Math.typographicBounds(
        for: #"\notARealCommand"#, fitting: .unspecified, font: font, style: .display)
    #expect(unsupported.width == 0)
}

@Test func displayMathBreaksOnlyAtSafeTopLevelBoundaries() {
    let formula = #"\frac{dy}{dx}=\frac{dy}{du}\frac{du}{dx}=f^{\prime}(g(x))g^{\prime}(x)"#
    let fragments = MathDocument.equationFragments(formula)
    #expect(fragments.count == 3)
    #expect(fragments.joined() == formula)
    #expect(MathDocument.equationFragments(#"\frac{x=1}{2}"#) == [#"\frac{x=1}{2}"#])
    #expect(MathDocument.equationFragments(#"\left(x=1\right)"#) == [#"\left(x=1\right)"#])
}
