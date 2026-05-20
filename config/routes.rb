Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope module: "compact_index" do
    scope ":version", constraints: { version: /v[1-9][0-9]*/ } do
      get "versions"     => "versions#show"
      get "names"        => "names#show"
      get "info/:gem"    => "info#show", constraints: { gem: /[^\/]+/ }
      get "cas/:sha256"  => "cas#show",  constraints: { sha256: /[0-9a-f]{64}/ }
    end
  end

  namespace :admin do
    get "indexers" => "indexers#index"
  end
end
