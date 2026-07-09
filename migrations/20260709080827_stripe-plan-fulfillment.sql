-- Fulfillment de planes SpecForge desde webhooks de Stripe (vía InsForge payments).
--
-- El success-URL del checkout es solo UX: la fuente durable de verdad son las
-- filas verificadas de payments.webhook_events. Este trigger actualiza
-- public.user_plans (la tabla de planes de specforge-api, misma base de datos)
-- cuando llega un checkout completado o se cancela una suscripción.

-- 1) Mapa price_id → tier. La API lo siembra al arrancar desde
--    STRIPE_PRICE_BUILDER / STRIPE_PRICE_PRO; sirve de fallback cuando un
--    evento no trae metadata.tier.
CREATE TABLE IF NOT EXISTS public.stripe_price_tiers (
  price_id TEXT PRIMARY KEY,
  tier TEXT NOT NULL CHECK (tier IN ('free', 'builder', 'pro'))
);

-- 2) RLS para que los usuarios autenticados creen/lean SUS checkout y portal
--    sessions (requisito del flujo createCheckoutSession con subject user).
ALTER TABLE payments.stripe_checkout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments.stripe_customer_portal_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users create their stripe checkout sessions"
  ON payments.stripe_checkout_sessions;
CREATE POLICY "users create their stripe checkout sessions"
ON payments.stripe_checkout_sessions
FOR INSERT TO authenticated
WITH CHECK (subject_type = 'user' AND subject_id = auth.uid()::text);

DROP POLICY IF EXISTS "users read their stripe checkout sessions"
  ON payments.stripe_checkout_sessions;
CREATE POLICY "users read their stripe checkout sessions"
ON payments.stripe_checkout_sessions
FOR SELECT TO authenticated
USING (subject_type = 'user' AND subject_id = auth.uid()::text);

DROP POLICY IF EXISTS "users create their stripe portal sessions"
  ON payments.stripe_customer_portal_sessions;
CREATE POLICY "users create their stripe portal sessions"
ON payments.stripe_customer_portal_sessions
FOR INSERT TO authenticated
WITH CHECK (subject_type = 'user' AND subject_id = auth.uid()::text);

DROP POLICY IF EXISTS "users read their stripe portal sessions"
  ON payments.stripe_customer_portal_sessions;
CREATE POLICY "users read their stripe portal sessions"
ON payments.stripe_customer_portal_sessions
FOR SELECT TO authenticated
USING (subject_type = 'user' AND subject_id = auth.uid()::text);

-- 3) Función de fulfillment.
CREATE OR REPLACE FUNCTION public.apply_specforge_plan_from_stripe()
RETURNS TRIGGER AS $$
DECLARE
  v_object JSONB;
  v_subject_type TEXT;
  v_subject_id TEXT;
  v_tier TEXT;
BEGIN
  IF NEW.provider IS DISTINCT FROM 'stripe'
     OR NEW.processing_status IS DISTINCT FROM 'processed' THEN
    RETURN NEW;
  END IF;

  v_object := NEW.payload -> 'data' -> 'object';

  -- Alta / upgrade: checkout completado
  IF NEW.event_type IN ('checkout.session.completed',
                        'checkout.session.async_payment_succeeded') THEN
    v_subject_type := v_object -> 'metadata' ->> 'insforge_subject_type';
    v_subject_id   := v_object -> 'metadata' ->> 'insforge_subject_id';
    v_tier         := v_object -> 'metadata' ->> 'tier';

    IF v_subject_type IS DISTINCT FROM 'user' OR v_subject_id IS NULL THEN
      RAISE WARNING 'specforge fulfillment: checkout % sin subject user resoluble',
        NEW.provider_event_id;
      RETURN NEW;
    END IF;
    IF v_tier IS NULL OR v_tier NOT IN ('builder', 'pro') THEN
      RAISE WARNING 'specforge fulfillment: checkout % sin metadata.tier valida (%)',
        NEW.provider_event_id, v_tier;
      RETURN NEW;
    END IF;

    INSERT INTO public.user_plans
      (id, owner_id, tier, period, credits_used, stripe_checkout_session_id, updated_at)
    VALUES
      (gen_random_uuid(), v_subject_id, v_tier, to_char(now(), 'YYYY-MM'), 0,
       COALESCE(v_object ->> 'id', ''), now())
    ON CONFLICT (owner_id) DO UPDATE SET
      tier = EXCLUDED.tier,
      stripe_checkout_session_id = EXCLUDED.stripe_checkout_session_id,
      updated_at = now();

  -- Baja: suscripción cancelada → vuelta a Free
  ELSIF NEW.event_type = 'customer.subscription.deleted' THEN
    v_subject_type := v_object -> 'metadata' ->> 'insforge_subject_type';
    v_subject_id   := v_object -> 'metadata' ->> 'insforge_subject_id';

    IF v_subject_id IS NULL THEN
      SELECT m.subject_type, m.subject_id
      INTO v_subject_type, v_subject_id
      FROM payments.customer_mappings m
      WHERE m.provider = NEW.provider
        AND m.environment = NEW.environment
        AND m.provider_customer_id = v_object ->> 'customer';
    END IF;

    IF v_subject_type IS DISTINCT FROM 'user' OR v_subject_id IS NULL THEN
      RAISE WARNING 'specforge fulfillment: subscription.deleted % sin subject resoluble',
        NEW.provider_event_id;
      RETURN NEW;
    END IF;

    UPDATE public.user_plans
    SET tier = 'free', updated_at = now()
    WHERE owner_id = v_subject_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS apply_specforge_plan_from_stripe_webhook ON payments.webhook_events;
CREATE TRIGGER apply_specforge_plan_from_stripe_webhook
  AFTER INSERT OR UPDATE ON payments.webhook_events
  FOR EACH ROW
  EXECUTE FUNCTION public.apply_specforge_plan_from_stripe();
