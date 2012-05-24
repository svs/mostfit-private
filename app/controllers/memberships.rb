class Memberships < Application
  # provides :xml, :yaml, :js

  def index
    @type =   Kernel.const_get("#{params[:type].camel_case}Membership")
    @club_model   =   @type.relationships["club"].parent_model
    @member_model = @type.relationships["member"].parent_model
    @member = @member_model.get(params[:member_id])
    @memberships = @type.all(:member_id => params[:member_id])
    display @memberships
  end


  def show(id)
    @membership = Membership.get(id)
    raise NotFound unless @membership
    display @membership
  end

  def new
    only_provides :html
    @membership = Membership.new
    display @membership
  end

  def edit(id)
    only_provides :html
    @membership = Membership.get(id)
    @type = @membership.type
    raise NotFound unless @membership
    display @membership
  end

  def create(membership)
    @membership = Membership.new(membership)
    if @membership.save
      redirect resource(@membership), :message => {:notice => "Membership was successfully created"}
    else
      message[:error] = "Membership failed to be created"
      render :new
    end
  end

  def update(id, membership)
    debugger
    @membership = Membership.get(id)
    membership[:upto] = SEP_DATE if membership[:upto].blank?
    raise NotFound unless @membership
    if @membership.update(membership)
       redirect resource(@membership.member)
    else
      display @membership, :edit
    end
  end

  def destroy(id)
    @membership = Membership.get(id)
    raise NotFound unless @membership
    if @membership.destroy
      redirect resource(:memberships)
    else
      raise InternalServerError
    end
  end

end # Memberships
