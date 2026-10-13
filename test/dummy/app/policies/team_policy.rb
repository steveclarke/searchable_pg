# frozen_string_literal: true

# ActionPolicy: a user sees the teams they belong to, the office every team.
class TeamPolicy < ActionPolicy::Base
  authorize :user, allow_nil: true

  relation_scope do |relation|
    next relation.none unless user
    user.office ? relation : relation.where(id: user.team_ids)
  end
end
