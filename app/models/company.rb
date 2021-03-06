require 'geocoder'

class Company < ActiveRecord::Base
  include SearchEngine

  # adds geocoding
  geocoded_by :address
  after_validation :geocode

  has_paper_trail :ignore => [:delta]
  acts_as_taggable_on :tags, :technologies
  sortable :created_at, :desc
  
	extend FriendlyId
  friendly_id :name, :use => :slugged
  has_attached_file :logo, :styles => { :medium => '220x220', :thumb => '48x48' }, 
    :storage => :s3,
    :bucket => ENV['S3_BUCKET'],
    :s3_credentials => {
      :access_key_id => ENV['S3_KEY'],
      :secret_access_key => ENV['S3_SECRET']
  }

  default_serialization_options :include => { :projects => {:include => [:tags, :technologies]}, 
                                              :groups => {:include => [:tags, :technologies]},
                                              :employees  => {:include => [:tags, :technologies]},
                                              :tags => {},
                                              :technologies => {}}

  has_many :company_projects
  has_many :projects, :through => :company_projects

  has_many :sponsorships
  has_many :groups, :through => :sponsorships

  has_many :employments
  has_many :employees, :through => :employments, :source => :person

  validates_presence_of :name
  
  def clean_address
    address.gsub(" ", "+").gsub(",", "")
  end

  def map_url
        "http://maps.googleapis.com/maps/api/staticmap?center=#{clean_address}&zoom=13&size=200x220&maptype=roadmap&markers=color:blue%7C#{clean_address}&sensor=false"
  end
  def google_maps_link
    "http://maps.google.com/maps?f=q&source=s_q&hl=en&geocode=&q=#{clean_address}"
  end

  def get_categories
    categories = ""

    if self.is_startup
      categories = categories + "startup,"
    end
    if self.is_company
      categories = categories + "company,"
    end
    if self.is_accelerator
      categories = categories + "accelerator,"
    end
    if self.is_investor
      categories = categories + "investor,"
    end
    if self.is_coworking
      categories = categories + "coworking,"
    end
    if self.is_organization
      categories = categories + "organization,"
    end
    if self.is_service
      categories = categories + "service,"
    end

    if categories.length < 1
      return "startup"
    else
      return categories[0, categories.length-1]
    end
  end

end

  public

    # Ghetto json method since the default_serialization_options seem broken
    def wwip_json(options={})
      
      #These conditionals are to fix a minor bug where websites lacking
      #http:// at the beginning were trying to link locally and hence were broken
      if self.url[0,3] == 'www'
        self.url = 'http://' + self.url
      end
      if self.jobs_url != nil && self.jobs_url[0,3] == 'www'
        self.jobs_url = 'http://' + self.jobs_url
      end
      return { :company => { 
        :user_id => self.id,
        :Lat => self.latitude,
        :Long => self.longitude,
        :location => self.address,
        :website => self.url,
        :jobs => self.jobs_url,
        :name => name,
        :category => get_categories,
        :is_group => false
      } }
    end

  # geocode_or_return Behaves like a db field, but it's actually dynamic
  def geocode_or_return
    logger.flush
    logger.debug "================================="
    logger.debug address
    logger.debug "latitude = ->#{self.latitude}<-"
    logger.debug "longitude = ->#{self.longitude}<-"

    if !self.latitude.nil? && !self.longitude.nil?
      # Lat/Long was already set previously
      logger.debug "CC1: Lat/Long is set"
      return true
    else
      # we'll try geocoding it now
      results = Geocoder.search(clean_address)
      if results.first.nil?
        logger.debug "CC2: Geocoding failed"
        # geocoding failed, use this as a signal value
        self.latitude = nil
        self.longitude = nil
        self.save!
        return false
      else
        logger.debug "CC3: Lat/Long is set"
        self.latitude = results.first.latitude
        self.longitude = results.first.longitude
        logger.debug "latitude2 = #{latitude}"
        logger.debug "longitude2 = #{longitude}"
        self.save!
        return true
      end
    end

  end

# == Schema Information
#
# Table name: companies
#
#  id                :integer(4)      not null, primary key
#  name              :string(255)
#  url               :string(255)
#  twitter           :string(255)
#  address           :text
#  description       :text
#  created_at        :datetime
#  updated_at        :datetime
#  logo_url          :string(255)
#  logo_file_name    :string(255)
#  logo_content_type :string(255)
#  logo_file_size    :integer(4)
#  logo_updated_at   :datetime
#  delta             :boolean(1)      default(TRUE), not null
#

