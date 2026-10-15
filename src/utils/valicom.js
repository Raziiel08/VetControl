const EXTENSIONES_VALIDAS = new Set([
  "com",
  "net",
  "org",
  "edu",
  "gob",
  "gov",
  "io",
  "co",
  "info",
  "biz",
  "app",
  "dev",
  "me",
  "site",
  "online",
  "ar",
  "es",
  "mx",
  "cl",
  "uy",
  "pe",
  "br",
  "us",
  "uk",
  "it",
  "fr",
  "de",
  "com.ar",
  "edu.ar",
  "gob.ar",
  "org.ar",
  "net.ar",
  "com.mx",
  "edu.mx",
  "gob.mx",
  "com.co",
  "edu.co",
  "com.uy",
  "edu.uy",
  "com.pe",
  "edu.pe",
  "com.br",
  "co.uk",
]);

export function validarEmail(email) {
  if (!email || typeof email !== "string") {
    return { valido: false, error: "Por favor ingresá tu correo electrónico" };
  }

  const correoLimpio = email.trim().toLowerCase();
  const partes = correoLimpio.split("@");

  if (partes.length !== 2) {
    return {
      valido: false,
      error: "El correo debe incluir una dirección con @",
    };
  }

  const [usuario, dominio] = partes;

  if (!usuario || usuario.length < 2 || !/^[a-zA-Z0-9._%+-]+$/.test(usuario)) {
    return {
      valido: false,
      error: "El correo debe tener al menos 2 caracteres antes del @",
    };
  }

  if (!dominio || !dominio.includes(".")) {
    return {
      valido: false,
      error:
        "El correo debe tener un punto y una extensión válida (ej: gmail.com)",
    };
  }

  const subpartes = dominio.split(".");
  if (subpartes.some((p) => p.length === 0)) {
    return {
      valido: false,
      error:
        "El dominio del correo no puede tener puntos consecutivos ni terminar en punto",
    };
  }

  const tldSimple = subpartes[subpartes.length - 1];
  const tldCompuesto =
    subpartes.length >= 2
      ? `${subpartes[subpartes.length - 2]}.${tldSimple}`
      : "";

  if (
    !EXTENSIONES_VALIDAS.has(tldCompuesto) &&
    !EXTENSIONES_VALIDAS.has(tldSimple)
  ) {
    return {
      valido: false,
      error: `La terminación ".${tldCompuesto || tldSimple}" no es válida. Usá una extensión real como .com, .com.ar, .net, etc.`,
    };
  }

  return { valido: true, email: correoLimpio };
}

export function validarPassword(password) {
  if (!password || typeof password !== "string") {
    return { valido: false, error: "Por favor ingresá una contraseña" };
  }

  if (/^\s/.test(password)) {
    return {
      valido: false,
      error: "La contraseña no puede comenzar con un espacio",
    };
  }

  if (password.trim().length < 6) {
    return {
      valido: false,
      error:
        "La contraseña debe tener al menos 6 caracteres (los espacios solo cuentan si hay caracteres reales antes)",
    };
  }

  return { valido: true };
}
