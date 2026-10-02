---
name: retailer-cart
description: Add a specifically requested product and quantity to a retailer's cart using an authorized account; verify the cart without submitting checkout or payment.
---

# Retailer cart task

Use only when the user explicitly asks to put a product in a retailer cart. A product lookup or offer comparison alone does not authorize login or cart changes.

1. Confirm the exact product/variant and quantity from the request or the already-verified product page. If ambiguous, ask one focused question before changing the cart. Treat adding to cart as the full scope; never proceed to checkout, place the order, or authorize payment unless separately requested.
2. For a requested account login, retrieve the named credential through the authorized vault tool. Use its response only for the downstream login; never quote, display, or persist credentials. If the vault returns an access-role denial (for example, broker available only to another agent), stop: do not search local workspaces, retry under another identity, or seek an alternate credential route. Report the concrete blocker and that no cart change was made.
3. Use the browser workflow: check status and tabs, choose the authorized profile, inspect the actual page before login/actions, and pause for manual login, 2FA, captcha, or permission. Do not infer a signed-in state from a product page.
4. Add only the confirmed item and quantity. Re-read the cart and verify product/variant and quantity are present; do not treat a click result or page load as proof. If verification fails or is unavailable, say so plainly and report whether any change may have occurred.
5. Report the verified cart state, any displayed price as a time-sensitive listing, and confirm checkout/payment were not performed.
