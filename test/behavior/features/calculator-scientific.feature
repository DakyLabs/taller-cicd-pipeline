Feature: Calculator advanced usage

  @wip
  Scenario: Use the cosine operation
    Given I open the calculator
    When I type cos(0)
    Then the result is 1
