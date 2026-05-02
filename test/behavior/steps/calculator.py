from behave import *

from app.calc import Calculator


@given('I open the calculator')
def step_impl(context):
    context.calc = Calculator()


@when('I type 2 + 2')
def step_impl(context):
    context.result = context.calc.add(2, 2)


@then('the result is 4')
def step_impl(context):
    assert context.result == 4


@when('I type {op1} + {op2}')
def step_impl(context, op1, op2):
    context.result = context.calc.add(int(op1), int(op2))


@then('the result is {res}')
def step_impl(context, res):
    assert context.result == int(res)
