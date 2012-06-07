# encoding: UTF-8
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__))) unless $LOAD_PATH.include?(File.expand_path(File.dirname(__FILE__)))


require 'rubygems'
require 'mongo'
require 'haml'
require 'mongo_mapper'
require 'sinatra'
require "sinatra/reloader" 
require 'sinatra/flash'
require 'sinatra-authentication'
require 'fast_gettext'

class MmUser
  key :name, String, :unique=>true
end

require File.dirname(__FILE__) + '/language_codes.rb'
require File.dirname(__FILE__) + '/model.rb'
require File.dirname(__FILE__) + '/upload.rb'

ENV['RACK_ENV'] = 'development'

module Rack
  Flash = true
end

require File.dirname(__FILE__) + '/config.rb'

enable :sessions, :logging

set :enviroment, :development
set :sinatra_authentication_view_path, Pathname(__FILE__).dirname.expand_path + "views/auth/"
set :public_folder, File.dirname(__FILE__) + '/static'



use Rack::Session::Cookie, :secret => "*** Transboard ***"



def _(value) 
  FastGettext.add_text_domain('transboard',:path=>'locale', :type=>:po)
  FastGettext.text_domain = 'transboard'
  FastGettext.available_locales = ['de','en','fr','es','gl_ES','en_US','en_UK'] # only allow these locales to be set (optional)
  FastGettext.locale = 'en'
  #puts value
  newValue =  FastGettext::Translation::_(value)
  puts newValue
  return newValue
end


#Mongoid.load!(File.dirname(__FILE__) + "/mongoid.yml")


#
# Views
#


get '/' do

  unless logged_in?
    projectTotal = Document.all().length

    haml :index, :format=>:html5, :locals => {
      :projectTotal => projectTotal,
      :switches => {
        :dashboard => false,
        :create_new_project => false,
      },
      :linkswitches => {
        :projects => true
      }
    }
  else
    redirect '/dashboard'
  end

end


get '/create_new_project' do
  login_required

  haml :upload, :format=>:html5, :locals => {
      :create_new_project_active=>"active",
      :switches => {
      },
      :linkSwitches => {
        :projects => true,
        :dashboard => true,
      }
    }
end


post '/uploadFile' do

  if params['myFile'].nil?
    flash[:uploadError] = 'please indicate a File'
    redirect '/create_new_project'
  end

  r = Upload::saveUpload(params, current_user.id)

  if not r[:errors].nil?
    flash[:uploadError] = r[:errors]
    redirect '/create_new_project'
  elsif (r[:length] <= 0)
    flash[:uploadError] = 'Empty file'
    redirect '/create_new_project'
  else
    flash[:stringsLoaded] = r[:length].to_s + " strings loaded"
    redirect '/editproject/' + r[:docId]
  end

end


get "/editproject/:id" do
  login_required

  doc = Model::getDocument(params[:id])
  puts doc

  haml :edit, :format=>:html5, :locals => {
    :doc=>doc,
    :switches=>{},
    :linkSwitches=>{
    }
  }
end


get "/editprojectoptions/:id" do
  login_required

  doc = Model::getDocument(params[:id])
  puts doc

  haml :edit, :format=>:html5, :locals => {
    :doc=>doc,
    :switches=>{}
  }
end


get "/delete/:id" do
  r = Document.update(params[:id], {:status=>"deleted"})
  return "OK"
end


get "/dashboard" do
  projects = Document.all(:status => { "$not" => /deleted/ })
  haml :list, :format=>:html5, :locals => {
    :projects=>projects,
    :switches=>{:dashboard=>true}
  }
end


get "/projects" do
  projects = Document.all()
  haml :list, :format=>:html5, :locals => {
    :projects=>projects,
    :projects_active=>"active"
  }
end


get "/download/:id" do
  content_type 'text/plain', :charset => 'utf-8'
  attachment 'translation.po'

  d = Document.find(params[:id])

  s = ""

  d.lines.each do |line|
    s += line.msgid + "\n"
  end

  return s
end


###############
# Static Pages
#
##############

get "/about" do
  haml :about, :format=>:html5, :locals => {}
end


