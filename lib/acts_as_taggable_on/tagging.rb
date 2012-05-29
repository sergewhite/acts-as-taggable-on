module ActsAsTaggableOn
  class Tagging < ::ActiveRecord::Base #:nodoc:
    acts_as_belongs_to_tenant

    attr_accessible :tag,
                    :tag_id,
                    :context,
                    :taggable,
                    :taggable_type,
                    :taggable_id,
                    :tagger,
                    :tagger_type,
                    :tagger_id,
                    :tenant_id

    belongs_to :tag, :class_name => 'ActsAsTaggableOn::Tag'
    belongs_to :taggable, :polymorphic => true
    belongs_to :tagger,   :polymorphic => true

    validates_presence_of :context
    validates_presence_of :tag_id

    validates_uniqueness_of :tag_id, :scope => [ :taggable_type, :taggable_id, :context, :tagger_id, :tagger_type ]

    after_create :increment_counter
    after_destroy :decrement_counter
    after_destroy :remove_unused_tags

    private
    
    def needs_for_update_counters?
      context == 'admins' && %w(Story Contact TwitterList).include?(taggable_type)
    end
    
    def increment_counter
      if needs_for_update_counters?
        if taggable_type == 'Story' && tag.respond_to?(:stories_count)
          tag.update_attribute(:stories_count, (tag.stories_count + 1))
        elsif taggable_type == 'Contact' && tag.respond_to?(:contacts_count)
          tag.update_attribute(:contacts_count, (tag.contacts_count + 1))
        elsif taggable_type == 'TwitterList' && tag.respond_to?(:lists_count)
          tag.update_attribute(:lists_count, (tag.lists_count + 1))
        end
      end
    end
    
    def decrement_counter
      if needs_for_update_counters?
        if taggable_type == 'Story' && tag.respond_to?(:stories_count) && tag.stories_count > 0
          tag.update_attribute(:stories_count, (tag.stories_count - 1))
        elsif taggable_type == 'Contact' && tag.respond_to?(:contacts_count) && tag.contacts_count > 0
          tag.update_attribute(:contacts_count, (tag.contacts_count - 1))
        elsif taggable_type == 'TwitterList' && tag.respond_to?(:lists_count) && tag.lists_count > 0
          tag.update_attribute(:lists_count, (tag.lists_count - 1))
        end
      end
    end

    def remove_unused_tags
      if ActsAsTaggableOn.remove_unused_tags
        if tag.taggings.count.zero?
          tag.destroy
        end
      end
    end
  end
end