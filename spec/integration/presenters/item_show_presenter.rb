require 'integration/presenters/item_presenter'

module IntegrationTest
  class ItemShowPresenter < Curlybars::Presenter
    attr_reader :item

    allow_methods :item

    def initialize(item)
      @item = ItemPresenter.new(item)
    end
  end
end
