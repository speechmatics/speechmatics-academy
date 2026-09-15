'use client'

import { useCallback, useEffect, useState } from 'react'

import type { IMicrophoneAudioTrack } from 'agora-rtc-react'
import { Check, Settings } from 'lucide-react'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

interface MicrophoneSelectorProps {
  localMicrophoneTrack: IMicrophoneAudioTrack | null
}

interface MicrophoneDevice {
  deviceId: string
  label: string
}

export function MicrophoneSelector({ localMicrophoneTrack }: MicrophoneSelectorProps) {
  const [devices, setDevices] = useState<MicrophoneDevice[]>([])
  const [currentDeviceId, setCurrentDeviceId] = useState('')
  const [isOpen, setIsOpen] = useState(false)

  const fetchMicrophones = useCallback(async () => {
    try {
      const AgoraRTC = (await import('agora-rtc-react')).default
      const microphones = await AgoraRTC.getMicrophones()

      setDevices(
        microphones.map((device) => ({
          deviceId: device.deviceId,
          label: device.label || `Microphone ${device.deviceId.slice(0, 5)}...`,
        })),
      )

      if (localMicrophoneTrack) {
        const currentLabel = localMicrophoneTrack.getTrackLabel()
        const currentDevice = microphones.find((device) => device.label === currentLabel)
        if (currentDevice) {
          setCurrentDeviceId(currentDevice.deviceId)
        }
      }
    } catch (error) {
      console.error('Error fetching microphones:', error)
    }
  }, [localMicrophoneTrack])

  useEffect(() => {
    if (localMicrophoneTrack) {
      fetchMicrophones()
    }
  }, [fetchMicrophones, localMicrophoneTrack])

  const handleDeviceChange = async (deviceId: string) => {
    if (!localMicrophoneTrack) return

    try {
      await localMicrophoneTrack.setDevice(deviceId)
      setCurrentDeviceId(deviceId)
    } catch (error) {
      console.error('Error changing microphone device:', error)
    }
  }

  useEffect(() => {
    const setupDeviceChangeListener = async () => {
      try {
        const AgoraRTC = (await import('agora-rtc-react')).default

        AgoraRTC.onMicrophoneChanged = async (changedDevice) => {
          await fetchMicrophones()

          if (changedDevice.state === 'ACTIVE' && localMicrophoneTrack) {
            await localMicrophoneTrack.setDevice(changedDevice.device.deviceId)
            setCurrentDeviceId(changedDevice.device.deviceId)
          } else if (
            changedDevice.device.label === localMicrophoneTrack?.getTrackLabel() &&
            changedDevice.state === 'INACTIVE'
          ) {
            const microphones = await AgoraRTC.getMicrophones()
            if (microphones[0] && localMicrophoneTrack) {
              await localMicrophoneTrack.setDevice(microphones[0].deviceId)
              setCurrentDeviceId(microphones[0].deviceId)
            }
          }
        }
      } catch (error) {
        console.error('Error setting up device change listener:', error)
      }
    }

    setupDeviceChangeListener()

    return () => {
      import('agora-rtc-react').then(({ default: AgoraRTC }) => {
        AgoraRTC.onMicrophoneChanged = undefined
      })
    }
  }, [fetchMicrophones, localMicrophoneTrack])

  if (devices.length <= 1) {
    return null
  }

  return (
    <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
      <DropdownMenuTrigger asChild>
        <Button
          variant='ghost'
          size='icon'
          className='h-10 w-10 rounded-full border border-border bg-secondary hover:bg-accent/10'
          title='Select microphone'
        >
          <Settings className='h-4 w-4 text-foreground' />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align='center' className='w-56 border-border bg-popover'>
        <div className='px-2 py-1.5 text-xs font-medium text-muted-foreground'>Microphone</div>
        {devices.map((device) => (
          <DropdownMenuItem
            key={device.deviceId}
            onClick={() => handleDeviceChange(device.deviceId)}
            className={
              device.deviceId === currentDeviceId
                ? 'cursor-pointer bg-accent/15 text-primary'
                : 'cursor-pointer text-foreground hover:bg-accent/10'
            }
          >
            <span className='truncate'>{device.label}</span>
            {device.deviceId === currentDeviceId && (
              <Check className='ml-auto h-3.5 w-3.5 text-primary' />
            )}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
