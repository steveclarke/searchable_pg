# frozen_string_literal: true

Rails.application.routes.draw do
  get "search", to: "search#index"
  resources :people, only: :show
  resources :teams, only: :show
  resources :events, only: :show
end
