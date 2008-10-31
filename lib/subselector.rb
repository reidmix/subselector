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
        (value.is_a?(Hash) and (value.keys & SUBSELECT_SQL.keys).first) || nil
      end
      
      def extract_subselect_model!(subselect)        
        subselect.delete(:model).to_s.classify.constantize rescue self
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
        if key = get_subselect_key(value)
          subselect = value[key]
          model = extract_subselect_model!(subselect)
          subselect.kind_of?(String) ? subselect : model.send(:construct_finder_sql, subselect)
        else
          quote_bound_value_without_subselect(value)
        end
      end
      alias_method_chain :quote_bound_value, :subselect
  end
end
