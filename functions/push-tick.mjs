import {dispatchPush} from '../push-core.mjs';
export default async()=>{await dispatchPush();return new Response('Done')};
export const config={schedule:'* * * * *'};
