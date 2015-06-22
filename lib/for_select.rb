module ForSelect
  extend ActiveSupport::Concern

  class MissingColumnError < StandardError
    attr_accessor :column_key, :object
    def initialize(key, object)
      self.column_key = key
      self.object = object
    end

    def message
      "#{column_key.to_s} is not a column on #{object} table.  Use a different column to sort or pluck"
    end
  end

  included do
  end

  module ClassMethods
    cattr_accessor :for_select_options

    def for_select(*args, &block)
      options = args.extract_options!
      options[:method] = block if block_given?
      self.for_select_options = options
      collection_object = args.first
      merge_for_select_options
      return_for_select(collection_object)
    end

    def add_for_select(options = {}, &block)
      options[:block] = block
      define_singleton_method :for_select do |*args, &block|
        options = options.merge(args.extract_options!)
        args.push(options)
        super(*args, &block)
      end
    end

    private
    def raise_wrong_column!(column_key)
      raise MissingColumnError.new(column_key, self) unless column_names.include?(column_key.to_s)
    end

    def determine_select_relation(select_relation)
      method = for_select_options[:method]
      post_block = for_select_options[:block]
      returned_scope = unless for_select_options[:no_options]
        add_in_options_for_select(select_relation)
      else
        if for_select_options[:method]
          method.respond_to?(:call) ? method.call(select_relation) : send(*method) if for_select_options[:method]
        else
          select_relation
        end
      end
      returned_scope = post_block.call(returned_scope) if post_block
      returned_scope
    end

    def return_for_select(collection_object)
      if collection_object
        collection_object_class = collection_object.respond_to?(:klass) ? collection_object.klass : collection_object
        f_key = respond_to?(:model_name) && "#{self.model_name.param_key}_id"
        if f_key && collection_object_class.column_names.include?(f_key)
          select_relation = where(:id => collection_object.pluck(f_key.to_sym).compact.uniq)
          determine_select_relation(select_relation)
        else
          none
        end
      else
        determine_select_relation(all)
      end
    end

    def add_in_options_for_select(select_relation)
      to_unshift, to_push = for_select_options[:unshift], for_select_options[:push]
      method = for_select_options[:method]
      select_relation = method.respond_to?(:call) ? method.call(select_relation) : send(*method) if method
      [:order_by, :name, :identifier].each do |key|
        raise_wrong_column!(for_select_options[key])
      end
      select_relation = select_relation.order(for_select_options[:order]).pluck(for_select_options[:name], for_select_options[:identifier])
      [:unshift, :push].each {|key| select_relation.send(key, for_select_options[key]) if for_select_options[key]}
      select_relation
    end

    def merge_for_select_options
      for_select_options.reverse_merge!(:name => :name, :identifier => :id, :order_direction => :asc, :no_options => false)
      if for_select_options[:order] && for_select_options[:order].is_a?(Hash)
        for_select_options[:order_by] = for_select_options[:order].first.first
        for_select_options[:order_direction] = for_select_options[:order].first.last
      end
      for_select_options[:order_by] ||= for_select_options[:name]
      for_select_options[:order] ||= {for_select_options[:order_by] => for_select_options[:order_direction]}
      for_select_options[:method] = case for_select_options[:method]
      when Symbol, String then [for_select_options[:method]]
      when Hash then for_select_options[:method].first
      else
        for_select_options[:method]
      end
      for_select_options
    end
  end
end

ActiveRecord::Base.send :include, ForSelect
