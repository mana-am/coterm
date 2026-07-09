import Testing

@testable import CotermFoundation

@Suite struct StringNilIfEmptyTests {
    @Test func emptyStringBecomesNil() {
        #expect("".nilIfEmpty == nil)
    }

    @Test func nonEmptyStringPassesThrough() {
        #expect("coterm".nilIfEmpty == "coterm")
    }

    @Test func whitespaceIsNotEmpty() {
        // nilIfEmpty only checks isEmpty; a space is non-empty and passes through.
        #expect(" ".nilIfEmpty == " ")
    }
}
