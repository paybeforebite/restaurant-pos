const config=window.SUPABASE_CONFIG||{};
const client=window.supabase&&config.url&&config.publishableKey?window.supabase.createClient(config.url,config.publishableKey):null;
window.SUPABASE_CLIENT=client;

function redirectToLogin(){
  if(window.location.pathname.endsWith("login.html")) return;
  const page=window.location.pathname.split("/").pop()||"index.html";
  const platformPages=["platform-dashboard.html","customers.html","subscriptions.html","analytics.html","settings.html"];
  const next=platformPages.includes(page)?page:"index.html";
  window.location.replace("login.html?next="+encodeURIComponent(next));
}

async function loadRestaurantSession(){
  if(!client) throw new Error("Supabase is not configured.");

  const {data:{session},error}=await client.auth.getSession();
  if(error) throw error;
  if(!session){redirectToLogin();return null;}

  const {data:platformAdmin,error:platformError}=await client
    .from("platform_admins")
    .select("user_id")
    .eq("user_id",session.user.id)
    .eq("is_active",true)
    .maybeSingle();

  if(platformError) throw platformError;
  window.IS_PLATFORM_ADMIN=Boolean(platformAdmin);

  const currentPage=window.location.pathname.split("/").pop()||"index.html";
  const platformPages=["platform-dashboard.html","customers.html","subscriptions.html","analytics.html","settings.html"];

  if(platformPages.includes(currentPage)&&!window.IS_PLATFORM_ADMIN){
    window.location.replace("index.html");
    return null;
  }

  const {data:m,error:me}=await client
    .from("restaurant_members")
    .select("restaurant_id,role,restaurants(name,slug)")
    .eq("user_id",session.user.id)
    .eq("is_active",true)
    .maybeSingle();

  if(me) throw me;

  if(!m){
    if(window.IS_PLATFORM_ADMIN){
      window.RESTAURANT_ID=null;
      window.RESTAURANT_ROLE="platform_admin";
      window.RESTAURANT_NAME="PayBeforeBite Admin";
      document.querySelectorAll("[data-user-email]").forEach(e=>e.textContent=session.user.email||"");
      document.querySelectorAll("[data-restaurant-name]").forEach(e=>e.textContent="PayBeforeBite Admin");
      if(!platformPages.includes(currentPage)){
        window.location.replace("platform-dashboard.html");
        return null;
      }
      return session;
    }

    await client.auth.signOut();
    throw new Error("Your account is not assigned to a restaurant. Please contact the administrator.");
  }

  window.RESTAURANT_ID=m.restaurant_id;
  window.RESTAURANT_ROLE=m.role;
  window.RESTAURANT_NAME=m.restaurants?.name||"Restaurant";

  document.querySelectorAll("[data-user-email]").forEach(e=>e.textContent=session.user.email||"");
  document.querySelectorAll("[data-restaurant-name]").forEach(e=>e.textContent=window.RESTAURANT_NAME);
  document.querySelectorAll("[data-platform-admin]").forEach(e=>e.style.display=window.IS_PLATFORM_ADMIN?"flex":"none");

  document.querySelectorAll("[data-logout]").forEach(b=>b.addEventListener("click",async()=>{
    b.disabled=true;
    await client.auth.signOut();
    location.replace("login.html");
  }));

  return session;
}

window.restaurantAuthReady=loadRestaurantSession();
