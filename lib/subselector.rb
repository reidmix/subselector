ActiveRecord::Base.class_eval do
  class << self
    private
      SUBSELECT_SQL = {
        :in => in_clause = 'in (?)',
        :not_in => "not #{in_clause}",
        :equal => equal_clause = '= (?)',
        :not_equal => "!#{equal_clause}"
      }

      def get_subselect_key(value)
        (value.respond_to?(:keys) and (value.keys & SUBSELECT_SQL.keys).first) || nil
      end
      
      def extract_subselect_model!(subselect)        
        subselect.delete(:model, &:raise).to_s.classify.constantize rescue self
      end

      def attribute_condition_with_subselect(argument)
        if key = get_subselect_key(argument)
          SUBSELECT_SQL[key]
        else
          attribute_condition_without_subselect(argument)
        end
      end
      alias_method_chain :attribute_condition, :subselect    

      def quote_bound_value_with_subselect(value)
        key = get_subselect_key(value)
        subselect = key ? value[key] : value
        model = extract_subselect_model!(subselect)

        if subselect.kind_of?(Hash)
          if operation = subselect.delete(:operation)
            model.send(:construct_calculation_sql, operation, subselect[:select], subselect)
          else
            model.send(:construct_finder_sql, subselect)
          end
        else
          key ? subselect : quote_bound_value_without_subselect(value)
        end
      end
      alias_method_chain :quote_bound_value, :subselect
  end
end
