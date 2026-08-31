import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { Express } from 'express';
import { AppModule } from './app.module';
import { assertProductionConfiguration } from './config/deployment.config';

async function bootstrap(): Promise<void> {
  assertProductionConfiguration(process.env);
  const app = await NestFactory.create(AppModule, { bodyParser: true });
  if (process.env.NODE_ENV === 'production') {
    const proxyHops = Math.max(Number(process.env.TRUST_PROXY_HOPS ?? 1), 1);
    (app.getHttpAdapter().getInstance() as Express).set('trust proxy', proxyHops);
  }
  app.setGlobalPrefix('v1');
  app.use(helmet());
  app.enableCors({
    origin: false,
    methods: ['GET', 'POST', 'DELETE'],
  });
  app.useGlobalPipes(new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  }));
  app.enableShutdownHooks();
  await app.listen(Number(process.env.PORT ?? 3000), '0.0.0.0');
}

void bootstrap();
