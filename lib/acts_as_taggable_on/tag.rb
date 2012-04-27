module ActsAsTaggableOn
  class Tag < ::ActiveRecord::Base
    acts_as_belongs_to_tenant

    include ActsAsTaggableOn::Utils

    attr_accessible :name, :description, :tenant_id, :parent_id

    ### ASSOCIATIONS:

    has_many :taggings, :dependent => :destroy, :class_name => 'ActsAsTaggableOn::Tagging'
    has_many :children, :class_name => "ActsAsTaggableOn::Tag", :foreign_key => "parent_id"
    belongs_to :parent, :class_name => "ActsAsTaggableOn::Tag", :foreign_key => "parent_id"

    ### CALLBACKS:

    before_destroy :nullify_parent_id_for_tags

    ### VALIDATIONS:

    validates_presence_of :name
    validates :name, :uniqueness => {:scope => :tenant_id, :case_sensitive => false}, :length => {:maximum => 255}
    validate :check_parent

    ### SCOPES:

    def self.named(name)
      by_tenant.where(["lower(name) = ?", name.downcase])
    end

    def self.named_any(list)
      by_tenant.where(list.map { |tag| sanitize_sql(["lower(name) = ?", tag.to_s.downcase]) }.join(" OR "))
    end

    def self.named_like(name)
      by_tenant.where(["name #{like_operator} ? ESCAPE '!'", "%#{escape_like(name)}%"])
    end

    def self.named_like_any(list)
      by_tenant.where(list.map { |tag| sanitize_sql(["name #{like_operator} ? ESCAPE '!'", "%#{escape_like(tag.to_s)}%"]) }.join(" OR "))
    end

    ### CLASS METHODS:

    def self.find_or_create_with_like_by_name(name)
      named_like(name).first || create(:name => name)
    end

    def self.find_or_create_all_with_like_by_name(*list)
      list = [list].flatten

      return [] if list.empty?

      existing_tags = Tag.named_any(list).all
      new_tag_names = list.reject do |name|
        name = comparable_name(name)
        existing_tags.any? { |tag| comparable_name(tag.name) == name }
      end
      created_tags  = new_tag_names.map { |name| Tag.create(:name => name) }

      existing_tags + created_tags
    end

    ### INSTANCE METHODS:

    def ==(object)
      super || (object.is_a?(Tag) && name == object.name)
    end

    def to_s
      name
    end

    def count
      read_attribute(:count).to_i
    end

    def merge_with other_tag
      ActsAsTaggableOn::Tag.transaction do
        #replace all tagging with id of new tag
        #do we need to check tenant here also
        taggable_ids = ActsAsTaggableOn::Tagging.where(:tag_id => self.id).map(&:taggable_id)
        ActsAsTaggableOn::Tagging.where("tag_id = #{other_tag.id} AND taggable_id NOT IN (#{taggable_ids.join(',')})").update_all(:tag_id => self.id)
        #delete old tag
        ActsAsTaggableOn::Tag.destroy(other_tag.id)
      end
    end


    class << self
      private
      def comparable_name(str)
        str.mb_chars.downcase.to_s
      end
    end

    private
    def check_parent
      errors.add(:base, "wrong parent. tag '#{self.class.find(self.parent_id).name}' is a child for this tag") if self.children.map(&:id).include?(self.parent_id)
      errors.add(:base, "wrong parent. parent can not point to self") if self.parent_id == self.id
    end

    def nullify_parent_id_for_tags
      self.tags.update_all(:parent_id => nil)
    end

  end
end
