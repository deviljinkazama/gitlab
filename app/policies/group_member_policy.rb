class GroupMemberPolicy < BasePolicy
  def rules
    return unless @user

    target_user = @subject.user
    group = @subject.group

    return if group.last_owner?(target_user)

    can_manage = Ability.allowed?(@user, :admin_group_member, group)

    if can_manage
      can! :update_group_member
      can! :destroy_group_member
    elsif @user == target_user
      can! :destroy_group_member
    end

    additional_rules!
  end

  def additional_rules!
    can_override = Ability.allowed?(@user, :override_group_member, @subject.group)

    if can_override
      can! :override_group_member if @subject.ldap?
      can! :update_group_member unless @subject.ldap? && !@subject.override?
    end
  end
end
