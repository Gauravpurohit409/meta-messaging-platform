# Meta App Review use case

Marquee is a desk a business uses to send WhatsApp template messages that Meta has already approved. The business uploads phone numbers only for people who opted in, and the desk sends the approved template to that list.

People opt out of marketing by replying STOP (or stop all, unsubscribe, cancel, end, quit, or opt out). The desk then does not send that person further marketing templates until they reply START.

The product is not a support inbox. It does not offer a free-form reply box or live chat. Inbound messages are stored only so opt-out and opt-in words can be honored.

Permissions used:

- `whatsapp_business_management` — read the WhatsApp Business account a client connects with Embedded Signup, submit message templates, and subscribe the app to that account's webhooks.
- `whatsapp_business_messaging` — register the client's phone number and send the approved template to the opted-in list.

`business_management` is not requested.
