# == Route Map
#
#                                   Prefix Verb   URI Pattern                                                                                       Controller#Action
#                                                 /assets                                                                                           Propshaft::Server
#                                  entries GET    /entries(.:format)                                                                                entries#index
#                                          POST   /entries(.:format)                                                                                entries#create
#                                new_entry GET    /entries/new(.:format)                                                                            entries#new
#                               edit_entry GET    /entries/:id/edit(.:format)                                                                       entries#edit
#                                    entry GET    /entries/:id(.:format)                                                                            entries#show
#                                          PATCH  /entries/:id(.:format)                                                                            entries#update
#                                          PUT    /entries/:id(.:format)                                                                            entries#update
#                                          DELETE /entries/:id(.:format)                                                                            entries#destroy
#                       rails_health_check GET    /up(.:format)                                                                                     rails/health#show
#                               keys_index GET    /keys/index(.:format)                                                                             keys#index
#                            keys_download GET    /keys/download(.:format)                                                                          keys#download
#                                     root GET    /                                                                                                 entries#index
#         turbo_recede_historical_location GET    /recede_historical_location(.:format)                                                             turbo/native/navigation#recede
#         turbo_resume_historical_location GET    /resume_historical_location(.:format)                                                             turbo/native/navigation#resume
#        turbo_refresh_historical_location GET    /refresh_historical_location(.:format)                                                            turbo/native/navigation#refresh
#            rails_postmark_inbound_emails POST   /rails/action_mailbox/postmark/inbound_emails(.:format)                                           action_mailbox/ingresses/postmark/inbound_emails#create
#               rails_relay_inbound_emails POST   /rails/action_mailbox/relay/inbound_emails(.:format)                                              action_mailbox/ingresses/relay/inbound_emails#create
#            rails_sendgrid_inbound_emails POST   /rails/action_mailbox/sendgrid/inbound_emails(.:format)                                           action_mailbox/ingresses/sendgrid/inbound_emails#create
#      rails_mandrill_inbound_health_check GET    /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#health_check
#            rails_mandrill_inbound_emails POST   /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#create
#             rails_mailgun_inbound_emails POST   /rails/action_mailbox/mailgun/inbound_emails/mime(.:format)                                       action_mailbox/ingresses/mailgun/inbound_emails#create
#           rails_conductor_inbound_emails GET    /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#index
#                                          POST   /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#create
#        new_rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/new(.:format)                                      rails/conductor/action_mailbox/inbound_emails#new
#            rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                      rails/conductor/action_mailbox/inbound_emails#show
# new_rails_conductor_inbound_email_source GET    /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)                              rails/conductor/action_mailbox/inbound_emails/sources#new
#    rails_conductor_inbound_email_sources POST   /rails/conductor/action_mailbox/inbound_emails/sources(.:format)                                  rails/conductor/action_mailbox/inbound_emails/sources#create
#    rails_conductor_inbound_email_reroute POST   /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)                               rails/conductor/action_mailbox/reroutes#create
# rails_conductor_inbound_email_incinerate POST   /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)                            rails/conductor/action_mailbox/incinerates#create
#                       rails_service_blob GET    /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)                               active_storage/blobs/redirect#show
#                 rails_service_blob_proxy GET    /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)                                  active_storage/blobs/proxy#show
#                                          GET    /rails/active_storage/blobs/:signed_id/*filename(.:format)                                        active_storage/blobs/redirect#show
#                rails_blob_representation GET    /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations/redirect#show
#          rails_blob_representation_proxy GET    /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)    active_storage/representations/proxy#show
#                                          GET    /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)          active_storage/representations/redirect#show
#                       rails_disk_service GET    /rails/active_storage/disk/:encoded_key/*filename(.:format)                                       active_storage/disk#show
#                update_rails_disk_service PUT    /rails/active_storage/disk/:encoded_token(.:format)                                               active_storage/disk#update
#                     rails_direct_uploads POST   /rails/active_storage/direct_uploads(.:format)                                                    active_storage/direct_uploads#create
#                            new_session GET    /unlock(.:format)                                                                                   sessions#new
#                                session POST   /unlock(.:format)                                                                                   sessions#create
#                                          DELETE /lock(.:format)                                                                                   sessions#destroy
Rails.application.routes.draw do
  resources :entries
  resources :encryption_keys

  # Routes for unlocking/locking the journal (session management for the decrypted key)
  resource :session, only: [ :new, :create, :destroy ], path_names: { new: "unlock" }
  # Map DELETE /lock to sessions#destroy for clarity
  delete "/lock", to: "sessions#destroy", as: "lock_session"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Add routes for key management
  namespace :keys do
    get :index
    get :download
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # API specific routes
  namespace :api do
    resources :entries, except: [ :edit, :update ] do # Keep index, show, new, create, destroy for API
      collection do
        get "edit/:id", to: "entries#edit", as: "edit"       # Map GET api/entries/edit/:id to api/entries#edit
        put ":id", to: "entries#update"                     # Map PUT api/entries/:id to api/entries#update
        patch ":id", to: "entries#update"                   # Map PATCH api/entries/:id to api/entries#update
        delete ":id", to: "entries#destroy"                  # Explicitly map DELETE api/entries/:id to api/entries#destroy
      end
    end
  end

  # Defines the root path route ("/")
  root "entries#index"
end
