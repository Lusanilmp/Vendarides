-- Activated only after the owner approved storing the worker credentials in Netlify.
grant execute on function public.claim_ride_push(text),public.settle_ride_push(text,uuid,boolean,uuid[]) to anon;
-- Each RPC validates the private worker token hash before reading or mutating its bounded queue.
