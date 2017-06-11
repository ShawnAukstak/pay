require 'test_helper'
require 'stripe_mock'
require 'minitest/mock'

class Pay::Billable::Stripe::Test < ActiveSupport::TestCase
  setup do
    StripeMock.start

    @billable = User.new

    @stripe_helper = StripeMock.create_test_helper
    @stripe_helper.create_plan(id: 'test-monthly', amount: 1500)
  end

  teardown do
    StripeMock.stop
  end

  test 'getting a stripe customer with a processor id' do
    customer = Stripe::Customer.create(
      email: 'johnny@appleseed.com',
      card: @stripe_helper.generate_card_token
    )

    @billable.processor_id = customer.id

    assert_equal @billable.stripe_customer, customer
  end

  test 'getting a stripe customer without a processor id' do
    assert_nil @billable.processor
    assert_nil @billable.processor_id

    @billable.email = 'gob.bluth@example.com'
    @billable.card_token = @stripe_helper.generate_card_token(
      brand: 'Visa',
      last4: '9191',
      exp_year: 1984
    )

    @billable.stripe_customer

    assert_equal @billable.processor, 'stripe'
    assert_not_nil @billable.processor_id
  end

  test 'can create a subscription' do
    @billable.card_token = @stripe_helper.generate_card_token(
      brand: 'Visa',
      last4: '9191',
      exp_year: 1984
    )
    @billable.subscribe('default', 'test-monthly')

    assert @billable.subscribed?
    assert_equal 'default', @billable.subscription.name
    assert_equal 'test-monthly', @billable.subscription.processor_plan
  end

  test 'can update their card' do
    customer = Stripe::Customer.create(
      email: 'johnny@appleseed.com',
      card: @stripe_helper.generate_card_token
    )

    @billable.stubs(:customer).returns(customer)
    card = @stripe_helper.generate_card_token(brand: 'Visa', last4: '4242')
    @billable.processor = 'stripe'
    @billable.update_card(card)

    assert @billable.card_brand == 'Visa'
    assert @billable.card_last4 == '4242'

    card = @stripe_helper.generate_card_token(
      brand: 'Discover',
      last4: '1117'
    )
    @billable.update_card(card)

    assert @billable.card_brand == 'Discover'
    assert @billable.card_last4 == '1117'
  end

  test 'retriving a stripe subscription' do
    @stripe_helper.create_plan(id: 'default', amount: 1500)

    customer = Stripe::Customer.create(
      email: 'johnny@appleseed.com',
      source: @stripe_helper.generate_card_token(brand: 'Visa', last4: '4242')
    )

    subscription = Stripe::Subscription.create(
      plan: 'default',
      customer: customer.id
    )

    assert_equal @billable.stripe_subscription(subscription.id), subscription
  end
end
