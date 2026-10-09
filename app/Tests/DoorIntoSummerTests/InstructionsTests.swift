import XCTest
@testable import DoorIntoSummer

final class InstructionsTests: XCTestCase {
    func testAnAtSessionOpensAnInstructionAndTheNextAtClosesIt() {
        XCTAssertEqual(instructions(in: "@a plus de lumière @b version nuit"),
                       [Instruction(session: "a", text: "@a plus de lumière"), Instruction(session: "b", text: "@b version nuit")])
    }

    func testASlashCommandBelongsToTheInstructionItSitsIn() {
        XCTAssertEqual(instructions(in: "@a x /lens-blur @b y /night z"),
                       [Instruction(session: "a", text: "@a x /lens-blur"), Instruction(session: "b", text: "@b y /night z")])
    }

    func testTheEndOfTheMessageClosesTheLastInstruction() {
        XCTAssertEqual(instructions(in: "  @a only one  "), [Instruction(session: "a", text: "@a only one")])
    }

    func testAMessageThatDoesNotOpenWithAtSessionIsNotAddressed() {
        XCTAssertNil(instructions(in: "no tag @a late"))
        XCTAssertNil(instructions(in: ""))
        XCTAssertNil(instructions(in: "@ nothing"))
    }

    func testASessionNamedTwiceGetsTwoInstructions() {
        XCTAssertEqual(instructions(in: "@a first @a second"),
                       [Instruction(session: "a", text: "@a first"), Instruction(session: "a", text: "@a second")])
    }

    func testAnAtInsideAWordIsNotATag() {
        XCTAssertEqual(instructions(in: "@a mail me@home.ch"), [Instruction(session: "a", text: "@a mail me@home.ch")])
    }
}
