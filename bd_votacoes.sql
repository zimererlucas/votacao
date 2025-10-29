-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.candidatos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  eleicao_id uuid,
  nome_completo text NOT NULL,
  criado_em timestamp with time zone DEFAULT now(),
  CONSTRAINT candidatos_pkey PRIMARY KEY (id),
  CONSTRAINT candidatos_eleicao_id_fkey FOREIGN KEY (eleicao_id) REFERENCES public.eleicoes(id)
);
CREATE TABLE public.cargo (
  nome text NOT NULL UNIQUE,
  CONSTRAINT cargo_pkey PRIMARY KEY (nome)
);
CREATE TABLE public.direito_voto (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid,
  eleicao_id uuid,
  ja_recebeu_token boolean DEFAULT false,
  CONSTRAINT direito_voto_pkey PRIMARY KEY (id),
  CONSTRAINT direito_voto_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.perfis(id),
  CONSTRAINT direito_voto_eleicao_id_fkey FOREIGN KEY (eleicao_id) REFERENCES public.eleicoes(id)
);
CREATE TABLE public.eleicoes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  titulo text NOT NULL,
  descricao text,
  data_comeco timestamp with time zone NOT NULL,
  data_fim timestamp with time zone NOT NULL,
  criado_em timestamp with time zone DEFAULT now(),
  CONSTRAINT eleicoes_pkey PRIMARY KEY (id)
);
CREATE TABLE public.perfis (
  id uuid NOT NULL,
  nome_completo text NOT NULL,
  cargo text NOT NULL,
  CONSTRAINT perfis_pkey PRIMARY KEY (id),
  CONSTRAINT perfis_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT perfis_cargo_fkey FOREIGN KEY (cargo) REFERENCES public.cargo(nome)
);
CREATE TABLE public.tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  eleicao_id uuid,
  token text NOT NULL UNIQUE,
  usado boolean DEFAULT false,
  criado_em timestamp with time zone DEFAULT now(),
  CONSTRAINT tokens_pkey PRIMARY KEY (id),
  CONSTRAINT tokens_eleicao_id_fkey FOREIGN KEY (eleicao_id) REFERENCES public.eleicoes(id)
);
CREATE TABLE public.votos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  eleicao_id uuid,
  candidato_id uuid,
  token text NOT NULL,
  timestamp timestamp with time zone DEFAULT now(),
  CONSTRAINT votos_pkey PRIMARY KEY (id),
  CONSTRAINT votos_eleicao_id_fkey FOREIGN KEY (eleicao_id) REFERENCES public.eleicoes(id),
  CONSTRAINT votos_candidato_id_fkey FOREIGN KEY (candidato_id) REFERENCES public.candidatos(id),
  CONSTRAINT votos_token_fkey FOREIGN KEY (token) REFERENCES public.tokens(token)
);