module Hobo

  module Model
    
    def self.included(base)
      Hobo.register_model(base)
      base.extend(ClassMethods)
      base.set_field_type({})
      class << base
        alias_method_chain :has_many, :defined_scopes
      end
    end

    module ClassMethods
      
      # include methods also shared by CompositeModel
      include ModelSupport::ClassMethods
      
      def method_added(name)
        # avoid error when running model generators before
        # db exists
        return unless connected? 
        
        aliased_name = "#{name}_without_hobo_type"
        return if name.to_s.ends_with?('without_hobo_type') or aliased_name.in?(instance_methods)
        
        type_wrapper = self.field_type(name)
        if type_wrapper && type_wrapper.is_a?(Class) && type_wrapper < String
          aliased_name = "#{name}_without_hobo_type"
          alias_method aliased_name, name
          define_method name do
            res = send(aliased_name)
            if res.nil?
              nil
            elsif res.respond_to?(:hobo_undefined?) && res.hobo_undefined?
              res
            else
              type_wrapper.new(res)
            end
          end
        end
      end
      
      def set_field_type(types)
        types.each_pair do |field, type|
          
          # TODO: Make this extensible
          type_class = case type
                       when :html; HtmlString
                       when :markdown; MarkdownString
                       when :textile; TextileString
                       when :password; PasswordString
                       else type
                       end
          
          field_types[field] = type_class
        end
      end
      
      
      def field_types
        @hobo_field_types ||= superclass.respond_to?(:field_types) ? superclass.field_types : {}
      end
      
      
      def set_default_order(order)
        @default_order = order
      end
      
      inheriting_attr_accessor :default_order, :id_name_options


      def never_show(*fields)
        @hobo_never_show ||= []
        @hobo_never_show.concat(fields.omap{to_sym})
      end


      def never_show?(field)
        @hobo_never_show and field.to_sym.in?(@hobo_never_show)
      end

      def set_creator_attr(attr)
        class_eval %{
          def creator
            #{attr};
          end
          def creator=(x)
            self.#{attr} = x;
          end
        }
      end 

      def set_search_columns(*columns)
        class_eval %{
          def self.search_columns
            %w{#{columns.omap{to_s} * ' '}}
          end
        }
      end
      

      def id_name(*args)
        @id_name_options = [] + args
        
        underscore = args.delete(:underscore)
        insenstive = args.delete(:case_insensitive)
        id_name_field = args.first || :name
        @id_name_column = id_name_field.to_s

        if underscore
          class_eval %{
            def id_name(underscore=false)
              underscore ? #{id_name_field}.gsub(' ', '_') : #{id_name_field}
            end
          }
        else
          class_eval %{
            def id_name(underscore=false)
              #{id_name_field}
            end
          }
        end

        key = "id_name#{if underscore; ".gsub('_', ' ')"; end}"
        finder = if insenstive
          "find(:first, :conditions => ['lower(#{id_name_field}) = ?', #{key}.downcase])"
        else
          "find_by_#{id_name_field}(#{key})"
        end

        class_eval %{
          def self.find_by_id_name(id_name)
            #{finder}
          end
        }

        model = self
        validate do
          erros.add id_name_field, "is taken" if model.find_by_id_name(name)
        end
        validates_format_of id_name_field, :with => /^[^_]+$/, :message => "cannot contain underscores" if
          underscore
      end


      def id_name?
        respond_to?(:find_by_id_name)
      end


      attr_reader :id_name_column

      
      
      def field_type(name)
        name = name.to_sym
        field_types[name] or
          reflections[name] or
          ((col = columns.find {|c| c.name == name.to_s}) and case col.type
                                                              when :boolean
                                                                TrueClass
                                                              when :text
                                                                Hobo::Text
                                                              else
                                                                col.klass
                                                              end)
      end
      
      
      def conditions(&b)
        ModelQueries.new(self).instance_eval(&b).to_sql
      end


      def find(*args, &b)
        if args.first.in?([:all, :first])
          if args.last.is_a? Hash
            options = args.last
            args[-1] = options = options.merge(:order => default_order) if options[:order] == :default
          else
            options = {}
          end
          
          if b
            super(args.first, options.merge(:conditions => conditions(&b)))
          else
            super(*args)
          end
        else
          super(*args)
        end
      end
      
      
      def count(*args, &b)
        if b
          sql = ModelQueries.new(self).instance_eval(&b).to_sql
          options = extract_options_from_args!(args)
          super(*args + [options.merge(:conditions => sql)])
        else
          super(*args)
        end
      end


      def subclass_associations(association, *subclass_associations)
        refl = reflections[association]
        for assoc in subclass_associations
          class_name = assoc.to_s.classify
          options = { :class_name => class_name, :conditions => "type = '#{class_name}'" }
          options[:source] = refl.source_reflection.name if refl.source_reflection
          has_many(assoc, refl.options.merge(options))
        end
      end

      def has_creator?
        instance_methods.include?('creator=') and instance_methods.include?('creator')
      end

      def search_columns
        cols = columns.omap{name}
        %w{name title body content}.select{|c| c.in?(cols) }
      end
      
      # This should really be a method on AssociationReflection
      def reverse_reflection(association_name)
        refl = reflections[association_name]
        return nil if refl.options[:conditions]
        
        reverse_macro = if refl.macro == :has_many
                          :belongs_to
                        elsif refl.macro == :belongs_to
                          :has_many
                        end
        refl.klass.reflections.values.find do |r|
          r.macro == reverse_macro and
            r.klass == self and 
            !r.options[:conditions] and
            r.primary_key_name == refl.primary_key_name
        end
      end
      
      
      class ScopedProxy
        def initialize(klass, scope={})
          @klass, @scope = klass, scope
        end
        
        def method_missing(name, *args, &block)
          klass.with_scope(@scope) do
            @klass.send(name, *args, &block)
          end
        end
      end
      (Object.instance_methods + 
       Object.private_instance_methods +
       Object.protected_instance_methods).each do |m|
        ScopedProxy.send(:undef_method, m) unless
          m.in?(%w{initialize method_missing}) || m.starts_with?('_')
      end
      
      attr_accessor :defined_scopes

      
      def def_scope(name, scope=nil, &block)
        @defined_scopes ||= {}
        @defined_scopes[name.to_sym] = block || scope
        
        meta_def(name) do |*args|
          ScopedProxy.new(self, block ? block.call(*args) : scope)
        end
      end
      
      
      module DefinedScopeProxyExtender
        
        attr_accessor :reflections
        
        def method_missing(name, *args, &block)
          scopes = proxy_reflection.klass.defined_scopes
          scope = scopes && scopes[name.to_sym]
          if scope
            scope = scope.call(*args) if scope.is_a?(Proc)
            
            # Calling directly causes self to get loaded
            assoc = Kernel.instance_method(:instance_variable_get).bind(self).call("@#{name}")
            unless assoc
              options = proxy_reflection.options
              has_many_conditions = options.has_key?(:condition)
              scope_conditions = scope.delete(:conditions)
              conditions = if has_many_conditions && scope_conditions
                             "(#{scope_conditions}) AND (#{has_many_conditions})"
                           else
                             scope_conditions || has_many_conditions
                           end
              
              options = options.merge(scope).update(:conditions => conditions,
                                                    :class_name => proxy_reflection.klass.name,
                                                    :foreign_key => proxy_reflection.primary_key_name)
              r = ActiveRecord::Reflection::AssociationReflection.new(:has_many,
                                                                      name,
                                                                      options,
                                                                      proxy_reflection.klass)
              @reflections ||= {}
              @reflections[name] = r
              
              assoc = if options.has_key?(:through)
                        ActiveRecord::Associations::HasManyThroughAssociation
                      else
                        ActiveRecord::Associations::HasManyAssociation
                      end.new(self.proxy_owner, r)
              
              # Calling directly causes self to get loaded
              Kernel.instance_method(:instance_variable_set).bind(self).call("@#{name}", assoc)
            end
            assoc
          else
            super
          end
        end
        
      end
      
      
      def has_many_with_defined_scopes(name, *args, &block)
        options = extract_options_from_args!(args)
        if options.has_key?(:extend) || block
          # Normal has_many
          has_many_without_defined_scopes(name, *args + [options], &block)
        else
          options[:extend] = DefinedScopeProxyExtender
          has_many_without_defined_scopes(name, *args + [options], &block)
        end
      end
    end
    
    
    def method_missing(name, *args, &b)
      val = super
      if val.nil?
        nil
      else
        type_wrapper = self.class.field_type(name)
        (type_wrapper && type_wrapper.is_a?(Class) && type_wrapper < String) ? type_wrapper.new(val) : val
      end
    end


    def created_by(user)
      self.creator ||= user if self.class.has_creator? and not user.guest?
    end


    def duplicate
      res = self.class.new
      res.instance_variable_set("@attributes", @attributes.dup)
      res.instance_variable_set("@new_record", nil) unless new_record?
      
      # Shallow copy of belongs_to associations
      for refl in self.class.reflections.values
        if refl.macro == :belongs_to and (target = self.send(refl.name))
          bta = ActiveRecord::Associations::BelongsToAssociation.new(res, refl)
          bta.replace(target)
          res.instance_variable_set("@#{refl.name}", bta)
        end
      end
      res
    end


    def same_fields?(other, *fields)
      fields.all?{|f| self.send(f) == other.send(f)}
    end
    
    def changed_fields?(other, *fields)
      fields.all?{|f| self.send(f) != other.send(f)}
    end
    
    def compose_with(object, use=nil)
      CompositeModel.new_for([self, object])
    end
    
    
    def typed_id
      id ? "#{self.class.name.underscore}_#{self.id}" : nil
    end
    
  end
end

