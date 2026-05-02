Feature: Calculator basic usage

  Scenario: Use the add operation
    Given I open the calculator
    When I type 2 + 2
    Then the result is 4

  Scenario Outline: Use the add operation multiple times
    Given I open the calculator
    When I type <op_1> + <op_2>
    Then the result is <res>

    Examples: Add numbers
      | op_1 | op_2 | res |
      | 2    | 2    | 4   |
      | 1    | 0    | 1   |
      | 1    | -1   | 0   |
